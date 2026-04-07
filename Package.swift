// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ios-libs",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "APIClient",
            targets: ["APIClient"]
        ),
        .library(
            name: "SharedKit",
            targets: ["SharedKit"]
        )
    ],
    dependencies: [
        // Swift OpenAPI Runtime - runtime library for generated code
        .package(
            url: "https://github.com/apple/swift-openapi-runtime",
            from: "1.9.0"
        ),
        // URLSession transport for the OpenAPI client
        .package(
            url: "https://github.com/apple/swift-openapi-urlsession",
            from: "1.0.0"
        ),
        // HTTPTypes for middleware implementations
        .package(
            url: "https://github.com/apple/swift-http-types",
            from: "1.0.0"
        )
    ],
    targets: [
        .target(
            name: "APIClient",
            dependencies: [
                "SharedKit",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types")
            ],
            swiftSettings: [
                .define("DebugBuild", .when(configuration: .debug))
            ]
        ),
        .target(
            name: "SharedKit",
            dependencies: [],
            swiftSettings: [
                .define("DebugBuild", .when(configuration: .debug))
            ]
        ),
        .testTarget(
            name: "APIClientTests",
            dependencies: [
                "APIClient",
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "HTTPTypes", package: "swift-http-types")
            ]
        ),
        .testTarget(
            name: "SharedKitTests",
            dependencies: ["SharedKit"]
        )
    ]
)
