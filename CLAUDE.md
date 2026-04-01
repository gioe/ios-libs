# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Build
swift build                        # Build all targets
swift build --product APIClient    # Build a specific product

# Test
swift test                         # Run all tests
swift test --filter AuthenticationMiddlewareTests  # Run a single test suite
swift test --filter "AuthenticationMiddlewareTests/testTokenInjection"  # Run a single test
```

Tests use Swift's `Testing` framework (`@Suite`, `@Test` macros), not XCTest.

## Architecture

Two Swift packages in one repo: **APIClient** and **SharedKit**.

### APIClient

Built on Apple's OpenAPI Generator ecosystem. Replace `Sources/APIClient/openapi.json` with a backend spec and the build plugin generates `Types.swift` and `Client.swift` at build time (`openapi-generator-config.yaml` sets `accessModifier: public` and `namingStrategy: idiomatic`).

**Bring-your-own-extensions pattern:** Consumers implement product-specific `+UI.swift` extensions on the generated types rather than this package exposing a product target. The `AIQAPIClient` product was removed for this reason.

`APIClientFactory` assembles the middleware chain:
1. Optional `TokenRefreshMiddleware` (caller-provided)
2. `AuthenticationMiddleware` — actor-based, injects Bearer tokens; distinguishes access vs. refresh token endpoints
3. `LoggingMiddleware` — redacts auth headers; defaults to `.debug` level in DEBUG builds, `.error` in Release

### SharedKit

A design system + component library + service layer.

**Design system layer** (`Sources/SharedKit/Design/`):
- `DesignSystem.swift` — spacing, corner radius, shadows, animation, icon size tokens as static constants
- `ColorPalette.swift` — WCAG 2.1 AA-compliant semantic colors with light/dark variants
- `Typography.swift` — heading/body/label/caption scale using `@ScaledMetric` for Dynamic Type
- `Theme.swift` — token protocols (`AppThemeProtocol` and sub-token structs) with `DefaultTheme` implementation
- `EnvironmentValues+Theme.swift` — injects theme via `@Environment(\.appTheme)`; swap theme at app root, no component changes needed

**ViewModel base** (`Sources/SharedKit/Architecture/`):
- `BaseViewModel` (open `ObservableObject`) — published `isLoading`/`error`, `handleError()`, `retry()`, `setLoading()`, validation helpers (`validationError(for:using:)`)
- Integrates with `ErrorRecorder` protocol (analytics/crash reporting) and `RetryableError` protocol (per-error retry logic)

**Services** (`Sources/SharedKit/Services/`):
- `BiometricAuthManager` — `@MainActor` actor; Face ID/Touch ID/Optic ID with passcode fallback
- `KeychainStorage` — `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, implements `SecureStorageProtocol`
- `NetworkMonitor` — singleton (`NetworkMonitor.shared`), `NWPathMonitor`-backed, publishes `isConnected` and `connectionType`

**Validators** (`Sources/SharedKit/Utilities/Validators.swift`) — email, password, phone, URL validation returning `ValidationResult`.
