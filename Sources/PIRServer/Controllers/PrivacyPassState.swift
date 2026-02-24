import Foundation
import Logging
import PrivacyPass

/// Manages Privacy Pass issuers and verifiers for each user tier.
///
/// Each tier gets its own RSA key pair. The issuer blind-signs token
/// requests, and the verifier checks tokens on PIR endpoints.
final class PrivacyPassState: Sendable {
    private let issuers: [UserTier: Issuer]
    private let verifiers: [UserTier: Verifier]
    private let publicKeys: [UserTier: Data]

    init(configuration: ServerConfiguration, logger: Logger) throws {
        var issuers: [UserTier: Issuer] = [:]
        var verifiers: [UserTier: Verifier] = [:]
        var publicKeys: [UserTier: Data] = [:]

        // Collect all unique tiers from the configuration.
        let tiers = Set(configuration.users.map(\.tier))

        for tier in tiers {
            logger.info("Generating Privacy Pass key pair for tier \(tier)")
            let privateKey = try PrivacyPass.PrivateKey()
            let publicKey = privateKey.publicKey

            issuers[tier] = Issuer(privateKey: privateKey)
            verifiers[tier] = Verifier(publicKey: publicKey)
            publicKeys[tier] = publicKey.derRepresentation
        }

        self.issuers = issuers
        self.verifiers = verifiers
        self.publicKeys = publicKeys
    }

    /// Build the token issuer directory response.
    func issuerDirectory() -> TokenIssuerDirectory {
        var keys: [TokenIssuerDirectory.TokenKey] = []
        for (tier, publicKeyData) in publicKeys {
            keys.append(TokenIssuerDirectory.TokenKey(
                tokenType: 2, // Publicly Verifiable Token
                tokenKeyID: tier.rawValue,
                tokenKey: publicKeyData.base64EncodedString()))
        }
        return TokenIssuerDirectory(tokenKeys: keys)
    }

    /// Get the DER-encoded public key for a tier.
    func publicKeyDER(for tier: UserTier) -> Data? {
        publicKeys[tier]
    }

    /// Issue a blind-signed token for the given tier.
    func issue(tokenRequestData: Data, for tier: UserTier) throws -> Data? {
        guard let issuer = issuers[tier] else { return nil }
        return try issuer.issue(tokenRequestData: tokenRequestData)
    }

    /// Verify a Privacy Pass token and return the tier it belongs to.
    func verify(tokenData: Data) -> UserTier? {
        for (tier, verifier) in verifiers {
            if verifier.verify(tokenData: tokenData) {
                return tier
            }
        }
        return nil
    }
}
