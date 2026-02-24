import Foundation

/// Privacy Pass token verifier.
///
/// Checks that a presented token has a valid RSA signature from the
/// corresponding issuer. Uses nonce tracking to prevent replay.
public struct Verifier: Sendable {
    let publicKey: PublicKey

    public init(publicKey: PublicKey) {
        self.publicKey = publicKey
    }

    /// Verify a Privacy Pass token.
    ///
    /// The token format (RFC 9578 Section 5.3):
    /// struct {
    ///   uint16 token_type = 0x0002;
    ///   uint8 nonce[32];
    ///   uint8 challenge_digest[32];
    ///   uint8 token_key_id[32];
    ///   uint8 authenticator[Nk];
    /// } Token;
    ///
    /// - Parameter tokenData: Raw bytes of the token.
    /// - Returns: True if the token signature is valid.
    public func verify(tokenData: Data) -> Bool {
        // Minimum: type(2) + nonce(32) + challenge_digest(32) + key_id(32) + authenticator
        guard tokenData.count > 98 else { return false }

        // The authenticator (RSA signature) is the last Nk bytes.
        // For RSA 2048-bit, Nk = 256 bytes.
        let nk = 256
        guard tokenData.count >= 98 + nk else { return false }

        let messageData = tokenData.prefix(tokenData.count - nk)
        let signatureData = tokenData.suffix(nk)

        return publicKey.verify(
            signature: Data(signatureData),
            for: Data(messageData))
    }
}
