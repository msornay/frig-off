import Foundation
import Testing
@testable import FrigOffKit

@Suite("DatabaseBuilder")
struct DatabaseBuilderTests {
    /// A tiny prefix for fast tests: 016200000 → 10 numbers only.
    static let testPrefixes = [
        BlockPrefix(localPrefix: "016200000", zone: "test"),
    ]

    @Test func blockDatabaseRowCount() {
        let db = DatabaseBuilder.buildBlockDatabase(prefixes: Self.testPrefixes)
        #expect(db.rows.count == 10)
    }

    @Test func blockDatabaseKeywordFormat() {
        let db = DatabaseBuilder.buildBlockDatabase(prefixes: Self.testPrefixes)
        let firstKeyword = String(data: db.rows[0].keyword, encoding: .utf8)
        #expect(firstKeyword == "+33162000000")
    }

    @Test func blockDatabaseValueIsOneByteBlock() {
        let db = DatabaseBuilder.buildBlockDatabase(prefixes: Self.testPrefixes)
        for row in db.rows {
            #expect(row.value.count == 1)
            #expect(row.value[0] == 1)
        }
    }

    @Test func identityDatabaseRowCount() {
        let db = DatabaseBuilder.buildIdentityDatabase(prefixes: Self.testPrefixes)
        #expect(db.rows.count == 10)
    }

    @Test func identityDatabaseValueDeserializes() throws {
        let db = DatabaseBuilder.buildIdentityDatabase(
            prefixes: Self.testPrefixes,
            label: "Démarchage",
            cacheExpiryMinutes: 1440)
        let row = db.rows[0]
        let identity = try CallIdentity(serializedBytes: row.value)
        #expect(identity.name == "Démarchage")
        #expect(identity.cacheExpiryMinutes == 1440)
        #expect(identity.category == .business)
    }

    @Test func identityDatabaseAllRowsShareSameValue() {
        let db = DatabaseBuilder.buildIdentityDatabase(prefixes: Self.testPrefixes)
        let firstValue = db.rows[0].value
        for row in db.rows {
            #expect(row.value == firstValue)
        }
    }

    @Test func totalNumbersHelper() {
        let prefixes = [
            BlockPrefix(localPrefix: "0162", zone: "a"),   // 1,000,000
            BlockPrefix(localPrefix: "09475", zone: "b"),  // 100,000
        ]
        #expect(DatabaseBuilder.totalNumbers(prefixes: prefixes) == 1_100_000)
    }

    @Test func emptyPrefixesProduceEmptyDatabase() {
        let db = DatabaseBuilder.buildBlockDatabase(prefixes: [])
        #expect(db.rows.isEmpty)
    }

    @Test func databaseCanSerialize() throws {
        let db = DatabaseBuilder.buildBlockDatabase(prefixes: Self.testPrefixes)
        let data = try db.serializedData()
        #expect(data.count > 0)
    }
}
