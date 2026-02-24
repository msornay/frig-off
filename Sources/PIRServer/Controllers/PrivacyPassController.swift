import Foundation
import Hummingbird
import Logging
import PrivacyPass

/// Handles Privacy Pass token endpoints for Live Caller ID Lookup.
///
/// Implements Publicly Verifiable Tokens using Blind RSA (RFC 9578).
/// iOS uses these tokens to authenticate PIR queries without revealing
/// the user's identity to the server on each request.
struct PrivacyPassController: Sendable {
    let state: PrivacyPassState
    let authenticator: UserAuthenticator
    let logger: Logger

    func addRoutes(to router: Router<some RequestContext>) {
        // Well-known directory for token issuer discovery.
        router.get(
            "/.well-known/private-token-issuer-directory",
            handler: handleIssuerDirectory)

        // Public key for the user's tier (used by the client to blind tokens).
        router.get("/token-key-for-user-token", handler: handleTokenKey)

        // Issue a blind-signed token.
        router.post("/issue", handler: handleIssue)
    }

    /// GET /.well-known/private-token-issuer-directory
    ///
    /// Returns the token issuer directory with the public key(s) for
    /// each tier. The client uses this to discover available token types.
    @Sendable
    func handleIssuerDirectory(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        let directory = state.issuerDirectory()
        let data = try JSONEncoder().encode(directory)
        return Response(
            status: .ok,
            headers: [.contentType: "application/json"],
            body: .init(byteBuffer: .init(data: data)))
    }

    /// GET /token-key-for-user-token
    ///
    /// Returns the DER-encoded SPKI public key for the user's tier.
    /// The client authenticates with a user tier token in the Authorization
    /// header to determine which tier's key to return.
    @Sendable
    func handleTokenKey(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        let tier = try authenticator.authenticateUserToken(request: request)
        guard let publicKeyData = state.publicKeyDER(for: tier) else {
            return Response(status: .notFound)
        }
        return Response(
            status: .ok,
            headers: [.contentType: "application/octet-stream"],
            body: .init(byteBuffer: .init(data: publicKeyData)))
    }

    /// POST /issue
    ///
    /// Accepts a blinded token request and returns a blind signature.
    /// The client can then unblind the signature to obtain a valid
    /// Privacy Pass token for subsequent PIR requests.
    @Sendable
    func handleIssue(
        request: Request,
        context: some RequestContext
    ) async throws -> Response {
        let tier = try authenticator.authenticateUserToken(request: request)

        let body = try await request.body.collect(upTo: 65_536) // 64 KB max
        let tokenRequestData = Data(buffer: body)

        guard let responseData = try state.issue(
            tokenRequestData: tokenRequestData, for: tier) else {
            return Response(status: .badRequest)
        }

        logger.debug("Issued Privacy Pass token for tier \(tier)")
        return Response(
            status: .ok,
            headers: [.contentType: "application/private-token-response"],
            body: .init(byteBuffer: .init(data: responseData)))
    }
}
