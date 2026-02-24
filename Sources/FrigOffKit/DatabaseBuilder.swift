import Foundation
import PrivateInformationRetrievalProtobuf
import SwiftProtobuf

/// Builds PIR keyword databases from ARCEP prefix definitions.
///
/// Produces two databases compatible with Apple's `PIRProcessDatabase`:
/// - **block**: each phone number maps to a 1-byte value (0x01 = block)
/// - **identity**: each phone number maps to a serialized `CallIdentity`
///   protobuf with the label "Démarchage" and category BUSINESS
public enum DatabaseBuilder {

    /// Build the block database: each number → 1-byte block flag.
    ///
    /// The output is a `KeywordDatabase` protobuf that can be serialized
    /// to a `.binpb` or `.txtpb` file for `PIRProcessDatabase`.
    public static func buildBlockDatabase(
        prefixes: [BlockPrefix]
    ) -> Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabase {
        var rows = [Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabaseRow]()
        for prefix in prefixes {
            for number in PrefixIterator(prefix: prefix) {
                let row = Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabaseRow.with { row in
                    row.keyword = Data(number.utf8)
                    var blockFlag = Data(count: 1)
                    blockFlag[0] = 1
                    row.value = blockFlag
                }
                rows.append(row)
            }
        }
        return Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabase.with { db in
            db.rows = rows
        }
    }

    /// Build the identity database: each number → serialized CallIdentity.
    ///
    /// The CallIdentity contains the label "Démarchage" with category BUSINESS
    /// and a cache expiry of 1440 minutes (24 hours).
    public static func buildIdentityDatabase(
        prefixes: [BlockPrefix],
        label: String = "Démarchage",
        cacheExpiryMinutes: UInt32 = 1440
    ) -> Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabase {
        // Pre-build the identity protobuf value since it's the same for all numbers.
        let identity = CallIdentity.with { id in
            id.name = label
            id.cacheExpiryMinutes = cacheExpiryMinutes
            id.category = .business
        }
        // Serialize once and reuse for all rows.
        let identityData: Data
        do {
            identityData = try identity.serializedData()
        } catch {
            fatalError("Failed to serialize CallIdentity: \(error)")
        }

        var rows = [Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabaseRow]()
        for prefix in prefixes {
            for number in PrefixIterator(prefix: prefix) {
                let row = Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabaseRow.with { row in
                    row.keyword = Data(number.utf8)
                    row.value = identityData
                }
                rows.append(row)
            }
        }
        return Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabase.with { db in
            db.rows = rows
        }
    }

    /// Write a KeywordDatabase to disk as binary protobuf.
    public static func write(
        database: Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabase,
        to path: String
    ) throws {
        let data = try database.serializedData()
        try data.write(to: URL(fileURLWithPath: path))
    }

    /// Write a KeywordDatabase to disk as text protobuf (.txtpb).
    public static func writeText(
        database: Apple_SwiftHomomorphicEncryption_Pir_V1_KeywordDatabase,
        to path: String
    ) throws {
        let text = database.textFormatString()
        try text.write(toFile: path, atomically: true, encoding: .utf8)
    }

    /// Total number of phone numbers across all given prefixes.
    public static func totalNumbers(prefixes: [BlockPrefix]) -> Int {
        prefixes.reduce(0) { $0 + $1.numberCount }
    }
}
