import Foundation
import Hummingbird
import HummingbirdTesting
import NIOCore
import Testing

@testable import PIRServer
@testable import PrivacyPass

/// Build a test application with users but no PIR usecases.
///
/// Privacy Pass, health, and auth endpoints work without database shards.
/// The empty usecases array means UsecaseStore loads nothing from disk.
private func withTestApp(
    _ body: @Sendable @escaping (any TestClientProtocol) async throws -> Void
) async throws {
    let config = ServerConfiguration(
        users: [
            .init(tier: .tier1, tokens: ["valid-token-tier1"]),
            .init(tier: .tier2, tokens: ["valid-token-tier2"]),
        ],
        usecases: [])
    let app = try buildApplication(
        configuration: config, hostname: "127.0.0.1", port: 0)
    try await app.test(.router, body)
}

// MARK: - Health

@Suite("Health endpoint")
struct HealthEndpointTests {
    @Test func returnsOK() async throws {
        try await withTestApp { client in
            let response = try await client.execute(
                uri: "/health", method: .get)
            #expect(response.status == .ok)
        }
    }
}

// MARK: - Issuer directory

@Suite("Issuer directory endpoint")
struct IssuerDirectoryTests {
    @Test func returnsValidJSON() async throws {
        try await withTestApp { client in
            let response = try await client.execute(
                uri: "/.well-known/private-token-issuer-directory",
                method: .get)
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "application/json")

            let data = Data(response.body.readableBytesView)
            let directory = try JSONDecoder().decode(
                TokenIssuerDirectory.self, from: data)
            #expect(directory.tokenKeys.count == 2)
        }
    }

    @Test func allKeysArePubliclyVerifiable() async throws {
        try await withTestApp { client in
            let response = try await client.execute(
                uri: "/.well-known/private-token-issuer-directory",
                method: .get)
            let data = Data(response.body.readableBytesView)
            let directory = try JSONDecoder().decode(
                TokenIssuerDirectory.self, from: data)

            for key in directory.tokenKeys {
                #expect(key.tokenType == 2)
            }
        }
    }

    @Test func containsBothTiers() async throws {
        try await withTestApp { client in
            let response = try await client.execute(
                uri: "/.well-known/private-token-issuer-directory",
                method: .get)
            let data = Data(response.body.readableBytesView)
            let directory = try JSONDecoder().decode(
                TokenIssuerDirectory.self, from: data)

            let ids = Set(directory.tokenKeys.map(\.tokenKeyID))
            #expect(ids.contains("tier1"))
            #expect(ids.contains("tier2"))
        }
    }
}

// MARK: - Token key

@Suite("Token key endpoint")
struct TokenKeyTests {
    @Test func validAuthReturnsDERKey() async throws {
        try await withTestApp { client in
            let response = try await client.execute(
                uri: "/token-key-for-user-token",
                method: .get,
                headers: [.authorization: "Bearer valid-token-tier1"])
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "application/octet-stream")
            // RSA 2048-bit DER-encoded SPKI public key is ~294 bytes.
            #expect(response.body.readableBytes > 200)
        }
    }

    @Test func invalidAuthReturns401() async throws {
        try await withTestApp { client in
            let response = try await client.execute(
                uri: "/token-key-for-user-token",
                method: .get,
                headers: [.authorization: "Bearer wrong-token"])
            #expect(response.status == .unauthorized)
        }
    }

    @Test func missingAuthReturns401() async throws {
        try await withTestApp { client in
            let response = try await client.execute(
                uri: "/token-key-for-user-token",
                method: .get)
            #expect(response.status == .unauthorized)
        }
    }

    @Test func differentTiersGetDifferentKeys() async throws {
        try await withTestApp { client in
            let r1 = try await client.execute(
                uri: "/token-key-for-user-token",
                method: .get,
                headers: [.authorization: "Bearer valid-token-tier1"])
            let r2 = try await client.execute(
                uri: "/token-key-for-user-token",
                method: .get,
                headers: [.authorization: "Bearer valid-token-tier2"])
            #expect(r1.status == .ok)
            #expect(r2.status == .ok)
            // Different tiers have independent RSA key pairs.
            let key1 = Data(r1.body.readableBytesView)
            let key2 = Data(r2.body.readableBytesView)
            #expect(key1 != key2)
        }
    }
}

// MARK: - Token issuance

@Suite("Token issuance endpoint")
struct TokenIssuanceTests {
    @Test func rejectsNoAuth() async throws {
        try await withTestApp { client in
            let body = ByteBuffer(bytes: [0x00, 0x02, 0x01]
                + [UInt8](repeating: 0xAB, count: 256))
            let response = try await client.execute(
                uri: "/issue", method: .post, body: body)
            #expect(response.status == .unauthorized)
        }
    }

    @Test func rejectsInvalidAuth() async throws {
        try await withTestApp { client in
            let body = ByteBuffer(bytes: [0x00, 0x02, 0x01]
                + [UInt8](repeating: 0xAB, count: 256))
            let response = try await client.execute(
                uri: "/issue",
                method: .post,
                headers: [.authorization: "Bearer bad-token"],
                body: body)
            #expect(response.status == .unauthorized)
        }
    }
}

// MARK: - PIR config endpoint

@Suite("PIR config endpoint")
struct ConfigEndpointTests {
    @Test func bearerFallbackReturnsOK() async throws {
        try await withTestApp { client in
            // Empty body → ConfigRequest with defaults (no usecases).
            // With no usecases loaded, returns empty config.
            let response = try await client.execute(
                uri: "/config",
                method: .post,
                headers: [.authorization: "Bearer valid-token-tier1"])
            #expect(response.status == .ok)
            #expect(response.headers[.contentType] == "application/x-protobuf")
        }
    }

    @Test func rejectsNoAuth() async throws {
        try await withTestApp { client in
            let response = try await client.execute(
                uri: "/config", method: .post)
            #expect(response.status == .unauthorized)
        }
    }

    @Test func rejectsInvalidAuth() async throws {
        try await withTestApp { client in
            let response = try await client.execute(
                uri: "/config",
                method: .post,
                headers: [.authorization: "Bearer nope"])
            #expect(response.status == .unauthorized)
        }
    }
}
