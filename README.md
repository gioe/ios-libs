# ios-libs

iOS Swift packages: `APIClient` (OpenAPI-generated HTTP client), `AIQAPIClient` (product-specific UI extensions), and `SharedKit` (shared UI components and utilities).

## Packages

### SharedKit

A collection of reusable SwiftUI components, design tokens, and utilities with no product-specific dependencies. Safe to import in any iOS project.

**Includes:** 13 SwiftUI components, design system (colors, typography, themes), extensions (Date, Int, Number, String, View), services (Biometric auth, Haptics, Keychain, Network monitor, Toast), and utilities (Validators, TimeProvider).

### APIClient

A generic OpenAPI-generated HTTP client. Provides type-safe request/response types, authentication middleware, and logging middleware.

**"Bring your own openapi.json" pattern:** The `openapi.json` bundled in `Sources/APIClient/` is the AIQ backend spec. To use `APIClient` with a different backend:

1. Replace `Sources/APIClient/openapi.json` with your own OpenAPI 3.x spec.
2. Replace `Sources/AIQAPIClient/Extensions/` with your own `+UI.swift` extension files (see [AIQAPIClient](#aiqapiclient) below).
3. The Swift OpenAPI Generator plugin re-generates all types at build time from your spec.

The `openapi-generator-config.yaml` sets `accessModifier: public` so generated types can be extended from outside the `APIClient` module.

### AIQAPIClient

Product-specific UI extensions over the generated `APIClient` types, packaged separately so that `APIClient` can be imported without pulling in AIQ-specific display logic.

**Contains:**
- `ConfidenceIntervalSchema+UI.swift` — formatting and accessibility helpers for confidence intervals
- `QuestionResponse+UI.swift` — display helpers and difficulty color names for questions
- `TestResultResponse+UI.swift` — score formatting, percentile rank, and completion time helpers
- `UserResponse+UI.swift` — full name, initials, location display, and education level helpers

**For a different backend:** Create a new target alongside `APIClient` (e.g., `MyAppAPIClient`) with your own `+UI.swift` extensions that extend your generated types. Your target should depend on `APIClient`; callers then import only `MyAppAPIClient`.

## Adding as an SPM Dependency

```swift
// In Package.swift or Xcode's package manager UI:
.package(url: "https://github.com/gioe/ios-libs", from: "<version>")
```

Then add the products you need to your target's dependencies:

| Use case | Product to import |
|---|---|
| Generic UI components only | `SharedKit` |
| AIQ HTTP client + UI extensions | `AIQAPIClient` (transitively imports `APIClient`) |
| AIQ HTTP client types only (no UI helpers) | `APIClient` |

```swift
// Example: app that uses SharedKit and the full AIQ client
.target(
    name: "MyApp",
    dependencies: [
        .product(name: "SharedKit", package: "ios-libs"),
        .product(name: "AIQAPIClient", package: "ios-libs"),
    ]
)
```

Importing `SharedKit` alone brings no product-specific symbols into scope.
