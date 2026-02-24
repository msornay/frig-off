import ArgumentParser
import Foundation
import Hummingbird
import ServiceLifecycle

@main
struct PIRServerCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pir-server",
        abstract: "Frig-Off PIR service for Live Caller ID Lookup",
        discussion: """
            Serves a Private Information Retrieval (PIR) service compatible with
            Apple's Live Caller ID Lookup (iOS 18+).

            The server loads preprocessed PIR database shards and responds to
            encrypted queries using the BFV homomorphic encryption scheme.
            The server never sees which phone number is being queried.

            Endpoints:
              POST /config   — PIR parameters and evaluation key status
              POST /key      — Upload evaluation keys
              POST /queries  — Process encrypted PIR queries
              POST /issue    — Privacy Pass token issuance

            Usage:
              pir-server --config config/service-config.json
            """)

    @Option(name: .shortAndLong, help: "Path to service-config.json.")
    var config: String = "config/service-config.json"

    @Option(name: .shortAndLong, help: "Hostname to bind to.")
    var hostname: String = "0.0.0.0"

    @Option(name: .shortAndLong, help: "Port to listen on (overridden by $PORT).")
    var port: Int = 8080

    mutating func run() async throws {
        // Respect Clever Cloud's $PORT environment variable.
        let effectivePort = ProcessInfo.processInfo
            .environment["PORT"]
            .flatMap(Int.init) ?? port

        let configuration = try ServerConfiguration.load(from: config)

        let app = try buildApplication(
            configuration: configuration,
            hostname: hostname,
            port: effectivePort)

        try await app.runService()
    }
}
