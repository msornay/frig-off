import Foundation

/// Server configuration loaded from service-config.json.
///
/// Matches the format used by Apple's live-caller-id-lookup-example.
struct ServerConfiguration: Codable, Sendable {
    /// A group of users sharing the same tier and token(s).
    struct UserGroup: Codable, Sendable {
        /// The tier name (e.g., "tier1").
        let tier: UserTier
        /// Bearer tokens that authenticate users in this tier.
        let tokens: [String]
    }

    /// A PIR usecase (e.g., "block" or "identity").
    struct Usecase: Codable, Sendable {
        /// Usecase identifier, typically the extension's bundle ID suffix
        /// (e.g., "net.frigoff.app.lookup.block").
        let name: String

        /// Prefix for processed shard files.
        /// Files are named `{fileStem}-{shardIndex}.bin` and
        /// `{fileStem}-{shardIndex}.params.txtpb`.
        let fileStem: String

        /// Number of database shards.
        let shardCount: Int

        /// How many config versions to keep (default: 2).
        let versionCount: Int?

        var effectiveVersionCount: Int { versionCount ?? 2 }
    }

    /// User groups with their authentication tokens.
    let users: [UserGroup]

    /// PIR usecases served by this instance.
    let usecases: [Usecase]

    /// Optional issuer request URI for Privacy Pass.
    let issuerRequestUri: String?

    init(users: [UserGroup], usecases: [Usecase], issuerRequestUri: String? = nil) {
        self.users = users
        self.usecases = usecases
        self.issuerRequestUri = issuerRequestUri
    }

    /// Load configuration from a JSON file.
    static func load(from path: String) throws -> ServerConfiguration {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let decoder = JSONDecoder()
        return try decoder.decode(ServerConfiguration.self, from: data)
    }
}

/// User tier levels for Privacy Pass token issuance.
///
/// Different tiers can have different rate limits (not enforced in V1).
enum UserTier: String, Codable, Sendable, Equatable, CaseIterable, Hashable {
    case tier1
    case tier2
    case tier3
}
