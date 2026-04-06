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
        // Swift OpenAPI Generator - build tool plugin
        .package(
            url: "https://github.com/apple/swift-openapi-generator",
            from: "1.10.4"
        ),
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
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "HTTPTypes", package: "swift-http-types")
            ],
            swiftSettings: [
                .define("DebugBuild", .when(configuration: .debug))
            ],
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
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
