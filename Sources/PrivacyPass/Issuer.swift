import Foundation

/// Privacy Pass token issuer using Blind RSA (RFC 9578).
///
/// The issuer blind-signs token requests from clients. The client
/// can then unblind the signature to obtain a valid token. The issuer
/// never sees the token's nonce, so it cannot link issuance to redemption.
public struct Issuer: Sendable {
    let privateKey: PrivateKey

    public init(privateKey: PrivateKey) {
        self.privateKey = privateKey
    }

    /// Issue a blind signature for a token request.
    ///
    /// The token request contains a blinded message. The issuer signs it
    /// without seeing the original message content.
    ///
    /// - Parameter tokenRequestData: Raw bytes of the token request
    ///   (blinded message from the client).
    /// - Returns: Raw bytes of the blind signature (token response).
    public func issue(tokenRequestData: Data) throws -> Data {
        // The token request format (RFC 9578 Section 5.1):
        // struct {
        //   uint16 token_type = 0x0002;
        //   uint8 truncated_token_key_id;
        //   uint8 blinded_msg[Nk];
        // } TokenRequest;
        //
        // We need to extract the blinded_msg and produce a blind signature.
        guard tokenRequestData.count >= 3 else {
            throw PrivacyPassError.invalidTokenRequest
        }

        // Skip token_type (2 bytes) and truncated_token_key_id (1 byte).
        let blindedMessage = tokenRequestData.dropFirst(3)

        let blindSignature = try privateKey.blindSign(Data(blindedMessage))

        return blindSignature
    }
}
