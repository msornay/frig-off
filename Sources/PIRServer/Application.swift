import Foundation
import Hummingbird
import HummingbirdCompression
import Logging
import PrivateInformationRetrieval

/// Build the Hummingbird application with all PIR service routes.
func buildApplication(
    configuration: ServerConfiguration,
    hostname: String,
    port: Int
) throws -> some ApplicationProtocol {
    let logger = Logger(label: "frig-off.pir-server")

    // Load PIR usecases (processed database shards).
    logger.info("Loading PIR usecases...")
    let usecaseStore = try UsecaseStore(configuration: configuration, logger: logger)
    logger.info("Loaded \(usecaseStore.usecaseNames.count) usecase(s): \(usecaseStore.usecaseNames.joined(separator: ", "))")

    // Initialize Privacy Pass state (per-tier issuers and verifiers).
    let privacyPassState = try PrivacyPassState(configuration: configuration, logger: logger)

    // Build user authenticator from config.
    let authenticator = UserAuthenticator(configuration: configuration)

    // Set up the router.
    let router = Router()

    // Response compression for large PIR config responses.
    router.addMiddleware {
        ResponseCompressionMiddleware(minimumResponseSizeToCompress: 256)
    }

    // PIR endpoints.
    let pirController = PIRController(
        usecaseStore: usecaseStore,
        authenticator: authenticator,
        privacyPassState: privacyPassState,
        logger: logger)
    pirController.addRoutes(to: router)

    // Privacy Pass endpoints.
    let privacyPassController = PrivacyPassController(
        state: privacyPassState,
        authenticator: authenticator,
        logger: logger)
    privacyPassController.addRoutes(to: router)

    // Health check.
    router.get("/health") { _, _ in
        HTTPResponse.Status.ok
    }

    let app = Application(
        router: router,
        configuration: .init(address: .hostname(hostname, port: port)),
        logger: logger)

    return app
}
