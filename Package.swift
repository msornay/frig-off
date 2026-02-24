// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "frig-off",
    products: [
        .executable(name: "generate-db", targets: ["GenerateDB"]),
        .library(name: "FrigOffKit", targets: ["FrigOffKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/apple/swift-homomorphic-encryption", branch: "release/1.1"),
        .package(url: "https://github.com/apple/swift-protobuf.git", from: "1.31.1"),
    ],
    targets: [
        .executableTarget(
            name: "GenerateDB",
            dependencies: [
                "FrigOffKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]),
        .target(
            name: "FrigOffKit",
            dependencies: [
                .product(name: "PrivateInformationRetrievalProtobuf", package: "swift-homomorphic-encryption"),
                .product(name: "SwiftProtobuf", package: "swift-protobuf"),
            ],
            exclude: ["protobuf"]),
        .testTarget(
            name: "FrigOffKitTests",
            dependencies: ["FrigOffKit"]),
    ])

#if canImport(Darwin)
package.platforms = [
    .macOS(.v15),
]
#endif
