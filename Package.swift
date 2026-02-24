// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "frig-off",
    products: [
        .executable(name: "generate-db", targets: ["GenerateDB"]),
        .executable(name: "pir-server", targets: ["PIRServer"]),
        .library(name: "FrigOffKit", targets: ["FrigOffKit"]),
        .library(name: "PrivacyPass", targets: ["PrivacyPass"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "3.10.0"),
        .package(url: "https://github.com/apple/swift-homomorphic-encryption", branch: "release/1.1"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.31.1"),
        .package(url: "https://github.com/hummingbird-project/hummingbird.git", from: "2.0.0"),
        .package(url: "https://github.com/hummingbird-project/hummingbird-compression.git", from: "2.0.0"),
        .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "GenerateDB",
            dependencies: [
                "FrigOffKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .executableTarget(
            name: "PIRServer",
            dependencies: [
                "FrigOffKit",
                "PrivacyPass",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdCompression", package: "hummingbird-compression"),
                .product(name: "HomomorphicEncryption", package: "swift-homomorphic-encryption"),
                .product(name: "HomomorphicEncryptionProtobuf", package: "swift-homomorphic-encryption"),
                .product(name: "PrivateInformationRetrieval", package: "swift-homomorphic-encryption"),
                .product(name: "PrivateInformationRetrievalProtobuf", package: "swift-homomorphic-encryption"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
                .product(name: "ServiceLifecycle", package: "swift-service-lifecycle"),
            ]),
        .target(
            name: "FrigOffKit",
            dependencies: [
                .product(name: "PrivateInformationRetrievalProtobuf", package: "swift-homomorphic-encryption"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            exclude: ["protobuf"]),
        .target(
            name: "PrivacyPass",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "_CryptoExtras", package: "swift-crypto"),
            ]),
        .testTarget(
            name: "FrigOffKitTests",
            dependencies: ["FrigOffKit"]),
        .testTarget(
            name: "PIRServerTests",
            dependencies: [
                "PIRServer",
                "PrivacyPass",
                .product(name: "HummingbirdTesting", package: "hummingbird"),
            ]),
    ])

#if canImport(Darwin)
package.platforms = [
    .macOS(.v15),
]
#endif
