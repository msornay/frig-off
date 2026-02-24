import Crypto
import Foundation
import _CryptoExtras

/// RSA 2048-bit private key for Privacy Pass Blind RSA token issuance.
///
/// Implements the server-side key for Publicly Verifiable Tokens
/// per RFC 9578 using Blind RSA signatures.
public struct PrivateKey: Sendable {
    let backing: _RSA.BlindSigning.PrivateKey

    /// Generate a new random RSA 2048-bit key pair.
    public init() throws {
        self.backing = try _RSA.BlindSigning.PrivateKey(keySize: .bits2048)
    }

    /// The corresponding public key.
    public var publicKey: PublicKey {
        PublicKey(backing: backing.publicKey)
    }

    /// Blind-sign a token request.
    ///
    /// Takes a blinded message from the client and produces a blind
    /// signature that the client can unblind.
    public func blindSign(_ message: Data) throws -> Data {
        let signature = try backing.blindSignature(for: message)
        return signature.rawRepresentation
    }
}
