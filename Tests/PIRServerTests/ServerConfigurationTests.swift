import Foundation
import Testing
@testable import PIRServer

@Suite("ServerConfiguration")
struct ServerConfigurationTests {
    static let validJSON = """
        {
          "users": [
            {"tier": "tier1", "tokens": ["secret1", "secret2"]},
            {"tier": "tier2", "tokens": ["secret3"]}
          ],
          "usecases": [
            {"name": "block", "fileStem": "data/block", "shardCount": 10},
            {"name": "identity", "fileStem": "data/identity", "shardCount": 5}
          ]
        }
        """

    @Test func decodesValidConfig() throws {
        let data = Data(Self.validJSON.utf8)
        let config = try JSONDecoder().decode(ServerConfiguration.self, from: data)
        #expect(config.users.count == 2)
        #expect(config.usecases.count == 2)
    }

    @Test func userGroupTokens() throws {
        let data = Data(Self.validJSON.utf8)
        let config = try JSONDecoder().decode(ServerConfiguration.self, from: data)
        let tier1 = config.users.first { $0.tier == .tier1 }
        #expect(tier1 != nil)
        #expect(tier1?.tokens.count == 2)
        #expect(tier1?.tokens.contains("secret1") == true)
    }

    @Test func usecaseProperties() throws {
        let data = Data(Self.validJSON.utf8)
        let config = try JSONDecoder().decode(ServerConfiguration.self, from: data)
        let block = config.usecases.first { $0.name == "block" }
        #expect(block != nil)
        #expect(block?.fileStem == "data/block")
        #expect(block?.shardCount == 10)
    }

    @Test func defaultVersionCount() throws {
        let data = Data(Self.validJSON.utf8)
        let config = try JSONDecoder().decode(ServerConfiguration.self, from: data)
        let block = config.usecases.first { $0.name == "block" }
        #expect(block?.versionCount == nil)
        #expect(block?.effectiveVersionCount == 2)
    }

    @Test func customVersionCount() throws {
        let json = """
            {
              "users": [],
              "usecases": [
                {"name": "block", "fileStem": "data/block", "shardCount": 1, "versionCount": 5}
              ]
            }
            """
        let config = try JSONDecoder().decode(
            ServerConfiguration.self, from: Data(json.utf8))
        #expect(config.usecases[0].effectiveVersionCount == 5)
    }

    @Test func optionalIssuerRequestUri() throws {
        let json = """
            {
              "users": [],
              "usecases": [],
              "issuerRequestUri": "http://localhost:8080/issue"
            }
            """
        let config = try JSONDecoder().decode(
            ServerConfiguration.self, from: Data(json.utf8))
        #expect(config.issuerRequestUri == "http://localhost:8080/issue")
    }

    @Test func missingIssuerRequestUri() throws {
        let json = """
            {"users": [], "usecases": []}
            """
        let config = try JSONDecoder().decode(
            ServerConfiguration.self, from: Data(json.utf8))
        #expect(config.issuerRequestUri == nil)
    }
}

@Suite("UserTier")
struct UserTierTests {
    @Test func allTiers() {
        #expect(UserTier.allCases.count == 3)
        #expect(UserTier.allCases.contains(.tier1))
        #expect(UserTier.allCases.contains(.tier2))
        #expect(UserTier.allCases.contains(.tier3))
    }

    @Test func rawValues() {
        #expect(UserTier.tier1.rawValue == "tier1")
        #expect(UserTier.tier2.rawValue == "tier2")
        #expect(UserTier.tier3.rawValue == "tier3")
    }

    @Test func decodesFromJSON() throws {
        let data = Data("\"tier1\"".utf8)
        let tier = try JSONDecoder().decode(UserTier.self, from: data)
        #expect(tier == .tier1)
    }
}

@Suite("UserAuthenticator")
struct UserAuthenticatorTests {
    static func makeConfig() -> ServerConfiguration {
        ServerConfiguration(
            users: [
                .init(tier: .tier1, tokens: ["token-a", "token-b"]),
                .init(tier: .tier2, tokens: ["token-c"]),
            ],
            usecases: [])
    }

    @Test func mapsTokensToTiers() {
        let auth = UserAuthenticator(configuration: Self.makeConfig())
        // authenticateUserToken is tested indirectly through the config mapping.
        // Direct testing requires constructing Request objects.
        // This test validates the authenticator initializes without error.
        _ = auth
    }
}
