import Crypto
import Foundation
import _CryptoExtras

/// RSA 2048-bit public key for Privacy Pass token verification.
public struct PublicKey: Sendable {
    let backing: _RSA.BlindSigning.PublicKey

    init(backing: _RSA.BlindSigning.PublicKey) {
        self.backing = backing
    }

    /// Initialize from DER-encoded SubjectPublicKeyInfo (SPKI) data.
    public init(derRepresentation: Data) throws {
        self.backing = try _RSA.BlindSigning.PublicKey(
            derRepresentation: derRepresentation)
    }

    /// DER-encoded SubjectPublicKeyInfo representation of this key.
    ///
    /// This is the format sent to clients for blinding token requests.
    public var derRepresentation: Data {
        Data(backing.derRepresentation)
    }

    /// Verify a token's RSA signature.
    public func verify(signature: Data, for message: Data) -> Bool {
        guard let sig = try? _RSA.BlindSigning.PublicKey.BlindSignature(
            rawRepresentation: signature) else {
            return false
        }
        return backing.isValidSignature(sig, for: message)
    }
}
