import Foundation
import Hummingbird

/// Authenticates requests using either user tier tokens or Privacy Pass tokens.
///
/// For /issue and /token-key-for-user-token: uses bearer tokens from config.
/// For /config, /key, /queries: uses Privacy Pass tokens.
struct UserAuthenticator: Sendable {
    /// Maps bearer tokens to their tier.
    private let tokenToTier: [String: UserTier]

    init(configuration: ServerConfiguration) {
        var mapping: [String: UserTier] = [:]
        for group in configuration.users {
            for token in group.tokens {
                mapping[token] = group.tier
            }
        }
        self.tokenToTier = mapping
    }

    /// Authenticate a request using the Authorization header bearer token.
    ///
    /// Used for Privacy Pass token acquisition endpoints where the client
    /// presents its user tier token directly.
    func authenticateUserToken(request: Request) throws -> UserTier {
        guard let auth = request.headers[.authorization] else {
            throw PIRServerError.unauthorized(reason: "Missing Authorization header")
        }
        let token = auth.hasPrefix("Bearer ")
            ? String(auth.dropFirst("Bearer ".count))
            : auth

        guard let tier = tokenToTier[token] else {
            throw PIRServerError.unauthorized(reason: "Invalid user token")
        }
        return tier
    }

    /// Authenticate a request using a Privacy Pass token.
    ///
    /// Used for PIR endpoints (/config, /key, /queries) where the client
    /// presents a previously issued Privacy Pass token.
    func authenticate(
        request: Request,
        privacyPassState: PrivacyPassState
    ) async throws -> UserTier {
        guard let auth = request.headers[.authorization] else {
            throw PIRServerError.unauthorized(reason: "Missing Authorization header")
        }

        // Extract the Privacy Pass token from the Authorization header.
        // Format: "PrivateToken token=<base64>"
        let prefix = "PrivateToken token="
        guard auth.hasPrefix(prefix),
              let tokenData = Data(base64Encoded: String(auth.dropFirst(prefix.count)))
        else {
            // Fall back to bearer token auth for development convenience.
            return try authenticateUserToken(request: request)
        }

        guard let tier = privacyPassState.verify(tokenData: tokenData) else {
            throw PIRServerError.unauthorized(reason: "Invalid Privacy Pass token")
        }
        return tier
    }
}
