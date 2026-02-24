import ArgumentParser
import Foundation
import FrigOffKit

@main
struct GenerateDB: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "generate-db",
        abstract: "Generate PIR databases from ARCEP NPV prefix list",
        discussion: """
            Expands French commercial call prefixes (ARCEP NPV ranges) into
            individual E.164 phone numbers and writes two PIR keyword databases:

              block.binpb    — phone number → block flag (1 byte)
              identity.binpb — phone number → CallIdentity protobuf

            These files are consumed by Apple's PIRProcessDatabase tool to
            produce optimized shards for the PIR service.
            """)

    @Option(name: .shortAndLong, help: "Output directory for database files.")
    var output: String = "."

    @Flag(name: .long, help: "Use text protobuf format (.txtpb) instead of binary.")
    var textFormat: Bool = false

    @Flag(name: .long, help: "Also generate PIRProcessDatabase config JSON files.")
    var generateConfigs: Bool = false

    @Flag(name: .long, help: "Only generate the block database (skip identity).")
    var blockOnly: Bool = false

    mutating func run() throws {
        let prefixes = allPrefixes
        let total = DatabaseBuilder.totalNumbers(prefixes: prefixes)
        let ext = textFormat ? "txtpb" : "binpb"

        print("ARCEP NPV prefix expansion")
        print("  Metropolitan prefixes: \(metropolitanPrefixes.count)")
        print("  Overseas prefixes:     \(overseasPrefixes.count)")
        print("  Total prefixes:        \(prefixes.count)")
        print("  Total phone numbers:   \(formatNumber(total))")
        print()

        let outputDir = output
        let fm = FileManager.default
        if !fm.fileExists(atPath: outputDir) {
            try fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        }

        // Block database
        let blockPath = "\(outputDir)/block.\(ext)"
        print("Generating block database...")
        let blockDB = DatabaseBuilder.buildBlockDatabase(prefixes: prefixes)
        if textFormat {
            try DatabaseBuilder.writeText(database: blockDB, to: blockPath)
        } else {
            try DatabaseBuilder.write(database: blockDB, to: blockPath)
        }
        let blockSize = try fm.attributesOfItem(atPath: blockPath)[.size] as? Int64 ?? 0
        print("  Written \(blockDB.rows.count) entries to \(blockPath) (\(formatBytes(blockSize)))")

        // Identity database
        if !blockOnly {
            let identityPath = "\(outputDir)/identity.\(ext)"
            print("Generating identity database...")
            let identityDB = DatabaseBuilder.buildIdentityDatabase(prefixes: prefixes)
            if textFormat {
                try DatabaseBuilder.writeText(database: identityDB, to: identityPath)
            } else {
                try DatabaseBuilder.write(database: identityDB, to: identityPath)
            }
            let identitySize = try fm.attributesOfItem(atPath: identityPath)[.size] as? Int64 ?? 0
            print("  Written \(identityDB.rows.count) entries to \(identityPath) (\(formatBytes(identitySize)))")
        }

        // PIRProcessDatabase configs
        if generateConfigs {
            let blockConfigPath = "\(outputDir)/block-config.json"
            try writeConfig(
                inputDatabase: blockPath,
                outputStem: "\(outputDir)/block",
                to: blockConfigPath)
            print("  Written \(blockConfigPath)")

            if !blockOnly {
                let identityConfigPath = "\(outputDir)/identity-config.json"
                try writeConfig(
                    inputDatabase: "\(outputDir)/identity.\(ext)",
                    outputStem: "\(outputDir)/identity",
                    to: identityConfigPath)
                print("  Written \(identityConfigPath)")
            }
        }

        print()
        print("Done. Next steps:")
        print("  1. Install PIRProcessDatabase:")
        print("     swift package experimental-install -c release --product PIRProcessDatabase")
        print("  2. Process the databases:")
        print("     PIRProcessDatabase \(outputDir)/block-config.json")
        if !blockOnly {
            print("     PIRProcessDatabase \(outputDir)/identity-config.json")
        }
    }
}

// MARK: - Config generation

private func writeConfig(inputDatabase: String, outputStem: String, to path: String) throws {
    let config: [String: Any] = [
        "rlweParameters": "n_4096_logq_27_28_28_logt_5",
        "inputDatabase": inputDatabase,
        "outputDatabase": "\(outputStem)-SHARD_ID.bin",
        "outputPirParameters": "\(outputStem)-pir-params-SHARD_ID.txtpb",
        "databaseType": "keyword",
        "shardCount": 10,
    ]
    let data = try JSONSerialization.data(
        withJSONObject: config, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: URL(fileURLWithPath: path))
}

// MARK: - Formatting helpers

private func formatNumber(_ n: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = " "
    return formatter.string(from: NSNumber(value: n)) ?? "\(n)"
}

private func formatBytes(_ bytes: Int64) -> String {
    if bytes < 1024 { return "\(bytes) B" }
    if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
    return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
}
