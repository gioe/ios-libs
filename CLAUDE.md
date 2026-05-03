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

Three Swift packages in one repo: **APIClient**, **SharedKit**, and **SharedKitTesting**.

### APIClient

Built on Apple's OpenAPI Generator ecosystem. Pre-generated `Types.swift` and `Client.swift` live in `Sources/APIClient/GeneratedSources/`. To regenerate after updating `Sources/APIClient/openapi.json`, run `swift package plugin --allow-writing-to-package-directory generate-code-from-openapi --target APIClient`. The generator config (`openapi-generator-config.yaml`) sets `accessModifier: public` and `namingStrategy: idiomatic`. The build tool plugin was removed to avoid Xcode plugin validation prompts in consumer projects.

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

**Validators** (`Sources/SharedKit/Utilities/Validators.swift`) — email, password, name, phone, URL, minimum length, and birth year validation returning `ValidationResult`.

**Testing helpers** (`Sources/SharedKit/Testing/`):
- `MockModeDetector` — reads `-UITestMockMode` from `ProcessInfo.processInfo.arguments`. Apps check `MockModeDetector.isMockMode` in their bootstrap to seed deterministic state for UI tests (saved nearby ZIP, mocked services, skipped permission prompts). UI tests opt in with `app.launchArguments.append(MockModeDetector.mockModeArgument)` before `app.launch()`. The detector intentionally has no scenario routing — apps that need scenarios layer their own enum on top.

### SharedKitTesting

A separate library target (`Sources/SharedKitTesting/`) carved out so consumer **UI test targets** can link XCTest-dependent helpers without inflating the main `SharedKit` product. Linked from a consumer's `LaughTrackUITests`-style target, not from the app target.

- `BaseAppStoreScreenshotTests` — open `XCTestCase` subclass that handles boilerplate for fastlane snapshot flows: instantiates `XCUIApplication`, appends `MockModeDetector.mockModeArgument`, calls `app.launch()`, exposes a coordinate-based `tap(x:y:)` helper. Subclasses override `prepareForSnapshot()` (to call `setupSnapshot(app)` from the locally-bundled `SnapshotHelper.swift`), `configureLaunchArguments()` (to layer extra flags), and implement the per-app `testGenerateAllScreenshots()` navigation. The coordinate-tap helper exists because on iOS 18+ SwiftUI surfaces `Text()` and `Button` labels as `accessibilityElements` rather than as UIView subviews, so `app.tabBars.buttons["Search"]`, `app.buttons["my-id"]`, and similar XCUI element queries don't reliably resolve.

### Consumer Integration

**SPM target name collisions:** Both `SharedKit` and `APIClient` target names will collide with consumer-local packages of the same name. Consumers must rename their local packages (e.g., `AIQSharedKit`, `AIQAPIClientCore`) before adding ios-libs as a dependency.

**View extension symbol leaks:** ios-libs SharedKit defines SwiftUI View extensions (typography, design system) that collide with identically-named extensions in consumer-local packages. Linking both to the same Xcode target causes "ambiguous use of" errors. The workaround is a **bridge target** pattern:
1. Create a separate SPM target (e.g., `AIQOfflineQueue`) that depends on ios-libs SharedKit
2. Use `@_implementationOnly import SharedKit` to prevent symbol leaks
3. Re-export needed types via `public typealias` declarations — this selectively exposes chosen symbols while `@_implementationOnly` keeps View extensions and other SharedKit symbols hidden from the app target
4. Link the bridge target (not SharedKit directly) to the consumer app target

**Cross-repo subagent limitations:** When working on consumer projects (e.g., aiq/ios) from the ios-libs working directory, background subagents may lack permission to edit files outside the primary working directory. Prefer making cross-repo edits directly rather than delegating to subagents.

**Cross-repo commit workflow:** When a task's code changes land entirely in a consumer repo (e.g., aiq/ios) rather than ios-libs, `tusk commit` cannot track those commits. In this case: (1) make edits directly in the consumer repo, (2) commit in the consumer repo using `git commit` with the `[TASK-<id>]` prefix, (3) use `tusk criteria done <cid> --skip-verify` to mark criteria complete, and (4) log a progress checkpoint noting the consumer repo and branch where changes live.

<!-- tusk-task-tools -->
## Tusk Task Lookup

**Do NOT use Claude Code's built-in `TaskList`, `TaskGet`, or `TaskUpdate` tools to look up or manage tasks.** Those tools manage background agent subprocesses, not tusk tasks.

Use the tusk CLI instead:
- `tusk task-list` — list tasks
- `tusk task-get <id>` — get a task by ID (accepts `506` or `TASK-506`)
- `tusk task-update <id>` — update a task
