// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ios-libs",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "APIClient",
            targets: ["APIClient"]
        ),
        // Product-specific library for the AIQ app.
        // Contains UI extensions over the generated APIClient types.
        // Replace openapi.json and add your own +UI extensions to adapt for a different backend.
        .library(
            name: "AIQAPIClient",
            targets: ["AIQAPIClient"]
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
            plugins: [
                .plugin(name: "OpenAPIGenerator", package: "swift-openapi-generator")
            ]
        ),
        // Product-specific UI extensions over the generated APIClient types.
        // Depends on APIClient so callers only need to import AIQAPIClient.
        .target(
            name: "AIQAPIClient",
            dependencies: ["APIClient"]
        ),
        .target(
            name: "SharedKit",
            dependencies: []
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
