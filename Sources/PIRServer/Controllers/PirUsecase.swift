import Foundation
import HomomorphicEncryption
import HomomorphicEncryptionProtobuf
import Logging
import PrivateInformationRetrieval
import PrivateInformationRetrievalProtobuf

/// Protocol for a loaded PIR usecase that can process queries.
protocol Usecase: Sendable {
    /// PIR configuration for this usecase (parameters, shard info).
    var pirConfig: Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Config { get }

    /// Process a single PIR request against this usecase.
    func process(
        request: Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Request,
        evaluationKeyStore: EvaluationKeyStore
    ) async throws -> Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Response
}

/// A PIR usecase backed by keyword PIR servers, one per shard.
///
/// Loads processed database shards from disk and handles encrypted
/// keyword PIR queries using the BFV homomorphic encryption scheme.
struct PirUsecase<PirScheme: IndexPirServer>: Usecase where PirScheme.Scheme: HeScheme {
    typealias Scheme = PirScheme.Scheme

    let context: Context<Scheme>
    let keywordParams: KeywordPirParameter
    let shards: [KeywordPirServer<PirScheme>]
    let configProto: Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Config

    var pirConfig: Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Config { configProto }

    /// Load a usecase from processed shard files on disk.
    ///
    /// Expects files named `{fileStem}-{shardIndex}.bin` and
    /// `{fileStem}-{shardIndex}.params.txtpb` for each shard.
    init(usecase: ServerConfiguration.Usecase, logger: Logger) throws {
        var loadedShards: [KeywordPirServer<PirScheme>] = []
        var loadedContext: Context<Scheme>?
        var loadedParams: KeywordPirParameter?
        var shardConfigs: [Apple_SwiftHomomorphicEncryption_Api_Pir_V1_PIRShardConfig] = []

        for shardIndex in 0..<usecase.shardCount {
            let paramsPath = "\(usecase.fileStem)-\(shardIndex).params.txtpb"
            let databasePath = "\(usecase.fileStem)-\(shardIndex).bin"

            logger.info("Loading shard \(shardIndex): params=\(paramsPath) db=\(databasePath)")

            // Load PIR parameters from text protobuf.
            let paramsText = try String(contentsOfFile: paramsPath, encoding: .utf8)
            let paramsProto = try Apple_SwiftHomomorphicEncryption_Pir_V1_PirParameters(
                textFormatString: paramsText)

            // Load processed database from binary file.
            let dbData = try Data(contentsOf: URL(fileURLWithPath: databasePath))

            // Initialize the keyword PIR server for this shard.
            let pirParams = try paramsProto.native()
            let context = try Context<Scheme>(
                encryptionParameters: pirParams.encryptionParameters)

            if loadedContext == nil {
                loadedContext = context
            }

            let processedDb = try ProcessedDatabase<Scheme>(
                from: dbData, context: context)
            let processedWithParams = ProcessedDatabaseWithParameters(
                database: processedDb, algorithm: pirParams.algorithm)

            let server = try KeywordPirServer<PirScheme>(
                context: context,
                processed: processedWithParams)

            loadedShards.append(server)

            if loadedParams == nil {
                loadedParams = pirParams.keywordPirParams
            }

            // Build shard config for the config response.
            var shardConfig = Apple_SwiftHomomorphicEncryption_Api_Pir_V1_PIRShardConfig()
            shardConfig.numEntries = UInt64(processedDb.entryCount)
            shardConfigs.append(shardConfig)
        }

        guard let context = loadedContext, let params = loadedParams else {
            throw PIRServerError.noShardsLoaded(usecase: usecase.name)
        }

        self.context = context
        self.keywordParams = params
        self.shards = loadedShards

        // Build the config proto for this usecase.
        var config = Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Config()
        config.pirShardConfigs = shardConfigs
        config.keywordPirParams = try params.proto()
        self.configProto = config
    }

    func process(
        request: Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Request,
        evaluationKeyStore: EvaluationKeyStore
    ) async throws -> Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Response {
        guard request.hasPirRequest else {
            throw PIRServerError.unsupportedRequestType
        }

        let pirRequest = request.pirRequest
        let shardIndex = Int(pirRequest.shardIndex)
        guard shardIndex >= 0, shardIndex < shards.count else {
            throw PIRServerError.invalidShardIndex(
                index: shardIndex, count: shards.count)
        }

        // Retrieve or use inline evaluation key.
        let evaluationKey: EvaluationKey<Scheme>
        if pirRequest.hasEvaluationKey {
            evaluationKey = try pirRequest.evaluationKey.native(context: context)
        } else if pirRequest.hasEvaluationKeyMetadata {
            let keyId = pirRequest.evaluationKeyMetadata.identifier
            guard let stored = evaluationKeyStore.get(keyId: keyId, context: context) as? EvaluationKey<Scheme> else {
                throw PIRServerError.evaluationKeyNotFound
            }
            evaluationKey = stored
        } else {
            throw PIRServerError.missingEvaluationKey
        }

        let query = try Query<Scheme>(from: pirRequest, context: context)
        let response = try shards[shardIndex].computeResponse(
            to: query, using: evaluationKey)

        var pirResponse = Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Response()
        pirResponse.pirResponse = try response.proto()
        return pirResponse
    }
}

/// Try to load a usecase, attempting UInt32 then UInt64 scalar types.
func loadUsecase(
    usecase: ServerConfiguration.Usecase,
    logger: Logger
) throws -> any Usecase {
    do {
        return try PirUsecase<MulPirServer<Bfv<UInt32>>>(
            usecase: usecase, logger: logger)
    } catch {
        logger.debug("UInt32 failed for \(usecase.name), trying UInt64: \(error)")
        return try PirUsecase<MulPirServer<Bfv<UInt64>>>(
            usecase: usecase, logger: logger)
    }
}
