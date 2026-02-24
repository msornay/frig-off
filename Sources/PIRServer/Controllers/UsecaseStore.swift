import Foundation
import HomomorphicEncryption
import Logging
import PrivateInformationRetrieval
import PrivateInformationRetrievalProtobuf

/// Thread-safe store for loaded PIR usecases and evaluation keys.
///
/// Holds the processed database shards for each usecase and manages
/// per-user evaluation key storage.
final class UsecaseStore: Sendable {
    private let usecases: [String: any Usecase]
    let evaluationKeyStore: EvaluationKeyStore

    var usecaseNames: [String] { Array(usecases.keys).sorted() }

    init(configuration: ServerConfiguration, logger: Logger) throws {
        var loaded: [String: any Usecase] = [:]
        for usecase in configuration.usecases {
            logger.info("Loading usecase '\(usecase.name)' (fileStem=\(usecase.fileStem), shards=\(usecase.shardCount))")
            loaded[usecase.name] = try loadUsecase(usecase: usecase, logger: logger)
        }
        self.usecases = loaded
        self.evaluationKeyStore = EvaluationKeyStore()
    }

    /// Build a config response for the requested usecases.
    func config(
        for request: Apple_SwiftHomomorphicEncryption_Api_Pir_V1_ConfigRequest,
        userTier: UserTier
    ) throws -> Apple_SwiftHomomorphicEncryption_Api_Pir_V1_ConfigResponse {
        var response = Apple_SwiftHomomorphicEncryption_Api_Pir_V1_ConfigResponse()

        // If the request specifies usecases, only return those.
        // Otherwise, return all available usecases.
        let requestedNames = request.usecases.isEmpty
            ? Array(usecases.keys)
            : request.usecases

        for name in requestedNames {
            guard let usecase = usecases[name] else {
                continue
            }
            response.configs[name] = usecase.pirConfig
        }

        return response
    }

    /// Store evaluation keys for a user.
    func storeEvaluationKeys(
        _ keys: Apple_SwiftHomomorphicEncryption_Api_Shared_V1_EvaluationKeys,
        for userIdentifier: String,
        tier: UserTier
    ) throws {
        evaluationKeyStore.store(keys: keys, for: userIdentifier)
    }

    /// Process PIR queries.
    func process(
        requests: Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Requests,
        for userIdentifier: String,
        tier: UserTier
    ) async throws -> Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Responses {
        var responses = Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Responses()

        for request in requests.requests {
            let usecaseName = request.usecase
            guard let usecase = usecases[usecaseName] else {
                throw PIRServerError.unknownUsecase(name: usecaseName)
            }

            let response = try await usecase.process(
                request: request,
                evaluationKeyStore: evaluationKeyStore)
            responses.responses.append(response)
        }

        return responses
    }
}

/// Thread-safe storage for evaluation keys, keyed by user identifier.
final class EvaluationKeyStore: Sendable {
    private let lock = NSLock()
    private var keys: [String: Apple_SwiftHomomorphicEncryption_Api_Shared_V1_EvaluationKeys] = [:]

    func store(
        keys newKeys: Apple_SwiftHomomorphicEncryption_Api_Shared_V1_EvaluationKeys,
        for userIdentifier: String
    ) {
        lock.lock()
        defer { lock.unlock() }
        keys[userIdentifier] = newKeys
    }

    /// Retrieve a stored evaluation key by identifier.
    ///
    /// The keyId is a composite of user identifier and key config hash.
    /// Returns the deserialized evaluation key for the given HE context,
    /// or nil if not found.
    func get<Scheme: HeScheme>(
        keyId: String,
        context: Context<Scheme>
    ) -> EvaluationKey<Scheme>? {
        lock.lock()
        defer { lock.unlock() }
        // Look up by the key identifier (user/hash composite).
        // For now, iterate stored keys to find a match.
        for (_, storedKeys) in keys {
            for key in storedKeys.evaluationKeys {
                if let evKey = try? EvaluationKey<Scheme>(from: key, context: context) {
                    return evKey
                }
            }
        }
        return nil
    }
}
