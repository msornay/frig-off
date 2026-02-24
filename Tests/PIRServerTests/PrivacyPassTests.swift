import Foundation
import Testing
@testable import PrivacyPass

@Suite("PrivacyPass key generation")
struct PrivacyPassKeyTests {
    @Test func generateKeyPair() throws {
        let privateKey = try PrivateKey()
        let publicKey = privateKey.publicKey

        // Public key should have a DER representation.
        #expect(!publicKey.derRepresentation.isEmpty)
    }

    @Test func publicKeyRoundTrips() throws {
        let privateKey = try PrivateKey()
        let der = privateKey.publicKey.derRepresentation

        let restored = try PublicKey(derRepresentation: der)
        #expect(restored.derRepresentation == der)
    }
}

@Suite("TokenIssuerDirectory")
struct TokenIssuerDirectoryTests {
    @Test func encodesAsJSON() throws {
        let directory = TokenIssuerDirectory(tokenKeys: [
            .init(tokenType: 2, tokenKeyID: "tier1", tokenKey: "AAAA=="),
        ])

        let data = try JSONEncoder().encode(directory)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("token-type"))
        #expect(json.contains("token-key-id"))
        #expect(json.contains("token-key"))
    }

    @Test func decodesFromJSON() throws {
        let json = """
            {
              "token-keys": [
                {"token-type": 2, "token-key-id": "tier1", "token-key": "abc123"}
              ]
            }
            """
        let directory = try JSONDecoder().decode(
            TokenIssuerDirectory.self, from: Data(json.utf8))
        #expect(directory.tokenKeys.count == 1)
        #expect(directory.tokenKeys[0].tokenType == 2)
        #expect(directory.tokenKeys[0].tokenKeyID == "tier1")
    }
}

@Suite("PrivacyPassError")
struct PrivacyPassErrorTests {
    @Test func errorDescriptions() {
        let errors: [(PrivacyPassError, String)] = [
            (.invalidTokenRequest, "Invalid token request format"),
            (.invalidToken, "Invalid token format"),
            (.keyGenerationFailed, "RSA key generation failed"),
        ]
        for (error, expected) in errors {
            #expect(error.description == expected)
        }
    }
}
