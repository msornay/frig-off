import Foundation
import Hummingbird
import Logging
import PrivateInformationRetrieval
import PrivateInformationRetrievalProtobuf
import SwiftProtobuf

/// Handles PIR-related HTTP endpoints: /config, /key, /queries.
struct PIRController: Sendable {
    let usecaseStore: UsecaseStore
    let authenticator: UserAuthenticator
    let privacyPassState: PrivacyPassState
    let logger: Logger

    func addRoutes(to router: Router<some RequestContext>) {
        router.post("/config", handler: handleConfig)
        router.post("/key", handler: handleKey)
        router.post("/queries", handler: handleQueries)
    }

    /// POST /config — Return PIR parameters for requested usecases.
    ///
    /// The client sends a ConfigRequest protobuf specifying which usecases
    /// it wants config for. The server responds with PIR parameters,
    /// encryption parameters, and evaluation key status.
    @Sendable
    func handleConfig(request: Request, context: some RequestContext) async throws -> Response {
        // Validate Privacy Pass token.
        let tier = try await authenticator.authenticate(
            request: request, privacyPassState: privacyPassState)

        let body = try await request.body.collect(upTo: 1_048_576) // 1 MB max
        let configRequest = try Apple_SwiftHomomorphicEncryption_Api_Pir_V1_ConfigRequest(
            serializedBytes: body)

        let configResponse = try usecaseStore.config(
            for: configRequest, userTier: tier)

        let responseData = try configResponse.serializedData()
        return Response(
            status: .ok,
            headers: [.contentType: "application/x-protobuf"],
            body: .init(byteBuffer: .init(data: responseData)))
    }

    /// POST /key — Upload evaluation keys for server-side computation.
    ///
    /// The client uploads HE evaluation keys that the server stores and
    /// uses for subsequent PIR query processing. Keys are stored per-user.
    @Sendable
    func handleKey(request: Request, context: some RequestContext) async throws -> Response {
        let tier = try await authenticator.authenticate(
            request: request, privacyPassState: privacyPassState)

        let userIdentifier = request.headers[.init("User-Identifier")!] ?? "anonymous"

        let body = try await request.body.collect(upTo: 10_485_760) // 10 MB max
        let evaluationKeys = try Apple_SwiftHomomorphicEncryption_Api_Shared_V1_EvaluationKeys(
            serializedBytes: body)

        try usecaseStore.storeEvaluationKeys(
            evaluationKeys,
            for: userIdentifier,
            tier: tier)

        logger.info("Stored evaluation keys for user \(userIdentifier)")
        return Response(status: .ok)
    }

    /// POST /queries — Process encrypted PIR queries.
    ///
    /// The client sends one or more encrypted PIR queries. Each query
    /// targets a specific usecase and shard. The server performs homomorphic
    /// computation over the encrypted query and returns encrypted results.
    /// The server never sees the plaintext phone number being queried.
    @Sendable
    func handleQueries(request: Request, context: some RequestContext) async throws -> Response {
        let tier = try await authenticator.authenticate(
            request: request, privacyPassState: privacyPassState)

        let userIdentifier = request.headers[.init("User-Identifier")!] ?? "anonymous"

        let body = try await request.body.collect(upTo: 10_485_760) // 10 MB max
        let requests = try Apple_SwiftHomomorphicEncryption_Api_Pir_V1_Requests(
            serializedBytes: body)

        let responses = try await usecaseStore.process(
            requests: requests,
            for: userIdentifier,
            tier: tier)

        let responseData = try responses.serializedData()
        logger.debug("Processed \(requests.requests.count) PIR query(ies) for user \(userIdentifier)")
        return Response(
            status: .ok,
            headers: [.contentType: "application/x-protobuf"],
            body: .init(byteBuffer: .init(data: responseData)))
    }
}
