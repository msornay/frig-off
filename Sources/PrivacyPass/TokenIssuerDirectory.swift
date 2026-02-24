import Foundation

/// The well-known token issuer directory response.
///
/// Served at `/.well-known/private-token-issuer-directory`.
/// Clients use this to discover available token types and public keys.
public struct TokenIssuerDirectory: Codable, Sendable {
    /// A token key entry in the directory.
    public struct TokenKey: Codable, Sendable {
        /// Token type identifier (2 = Publicly Verifiable Token).
        public let tokenType: UInt16

        /// Identifier for this key (maps to a user tier).
        public let tokenKeyID: String

        /// Base64-encoded DER public key (SPKI format).
        public let tokenKey: String

        enum CodingKeys: String, CodingKey {
            case tokenType = "token-type"
            case tokenKeyID = "token-key-id"
            case tokenKey = "token-key"
        }

        public init(tokenType: UInt16, tokenKeyID: String, tokenKey: String) {
            self.tokenType = tokenType
            self.tokenKeyID = tokenKeyID
            self.tokenKey = tokenKey
        }
    }

    /// Available token keys.
    public let tokenKeys: [TokenKey]

    enum CodingKeys: String, CodingKey {
        case tokenKeys = "token-keys"
    }

    public init(tokenKeys: [TokenKey]) {
        self.tokenKeys = tokenKeys
    }
}
