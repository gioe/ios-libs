---
name: scaffold
description: Scaffold a greenfield iOS app project with ios-libs integration — interactive Q&A, file generation, and compilation verification
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Scaffold — Greenfield iOS App Generator

Generates a compilable iOS app project pre-wired with ios-libs (SharedKit + APIClient). Conducts an interactive interview, then writes Package.swift, App.swift, bridge target, and supporting files into the target directory.

## Step 0: Parse Target Path

The user provides a directory path after `/scaffold`. It may be absolute or relative to the ios-libs project root.

If no argument was provided, ask:

> Where should the new project be created? Provide an absolute path or a path relative to this repo's root (e.g., `../my-new-app`).

**Resolve to an absolute path:**

```bash
tusk path   # prints path to tasks.db; project root is its parent
```

If relative, prepend the project root. If absolute, use as-is. Store as `TARGET_PATH`.

**Validate or create:**

```bash
ls "$TARGET_PATH" 2>/dev/null || mkdir -p "$TARGET_PATH"
```

If the directory exists and is non-empty, warn the user:

> The directory `$TARGET_PATH` already exists and contains files. Scaffold will overwrite conflicting files. Continue?

Wait for confirmation before proceeding.

## Step 1: Q&A — Identity and Navigation

Use AskUserQuestion with **3 questions**:

1. **App Name** (header: "App name")
   - Options: `Acme` (description: "Example app name"), `MyApp` (description: "Simple default name")
   - The user will likely pick "Other" and type their app name
   - This determines the module prefix and directory names

2. **Bundle ID Prefix** (header: "Bundle ID")
   - Options: `com.example` (description: "Default placeholder prefix"), `com.yourcompany` (description: "Replace 'yourcompany' with yours")
   - The user will likely pick "Other" and type their actual prefix (e.g., `com.acme`)
   - Combined with app name lowercase to form full bundle ID: `{prefix}.{appname-lowercase}`

3. **Navigation Pattern** (header: "Navigation")
   - `CoordinatedNavigationStack (Recommended)` — description: "Type-safe routing with NavigationCoordinator from SharedKit. Supports push, pop, sheet, and full-screen cover via a Route enum."
   - `TabView + NavigationStack` — description: "Tab-based layout with independent NavigationStack per tab. Good for apps with 3-5 distinct sections."
   - `Simple NavigationStack` — description: "Basic NavigationStack with no coordinator. Good for simple apps or prototypes."

Store answers as `APP_NAME`, `BUNDLE_ID_PREFIX`, and `NAV_PATTERN`.

## Step 2: Q&A — SharedKit Feature Selection

AskUserQuestion supports max 4 options, so split into **two calls**.

**Call 2a — Core Services** (header: "Core services", multiSelect: true):
- `NetworkMonitor` — description: "Singleton that publishes connectivity status via NWPathMonitor"
- `KeychainStorage` — description: "Secure token/credential storage with kSecAttrAccessibleWhenUnlockedThisDeviceOnly"
- `BiometricAuth` — description: "Face ID / Touch ID / Optic ID authentication with passcode fallback"
- `ToastManager` — description: "In-app toast notification system"

**Call 2b — Additional Features** (header: "Extras", multiSelect: true):
- `HapticManager` — description: "Device haptic feedback for UI interactions"
- `OfflineOperationQueue` — description: "Queue operations while offline, replay when connectivity returns"
- `DataCache + ImageCache` — description: "Generic data caching and async image caching"
- `AppStateStorage` — description: "Thread-safe UserDefaults wrapper for app state persistence"

Store combined selections as `SELECTED_FEATURES` (array).

## Step 3: Q&A — API and Auth Strategy

Use AskUserQuestion with **2 questions**:

1. **API Strategy** (header: "API layer")
   - `OpenAPI Generated (Recommended)` — description: "Full APIClientFactory integration with generated types from an OpenAPI spec"
   - `Manual networking` — description: "No ios-libs APIClient dependency — you'll write your own networking layer"
   - `None / Later` — description: "Skip API setup entirely; add it later"

2. **Auth Strategy** (header: "Auth")
   - `Token-based Bearer (Recommended)` — description: "AuthenticationMiddleware + optional TokenRefreshMiddleware for JWT/OAuth flows"
   - `API Key` — description: "Simple API key injected as a header"
   - `None / Later` — description: "Skip auth setup; add it later"

Store as `API_STRATEGY` and `AUTH_STRATEGY`.

**If API_STRATEGY is "None / Later"**, ignore AUTH_STRATEGY (treat as None).

## Step 4: Derive App Prefix

Derive `PREFIX` from `APP_NAME`:
- Strip non-alphanumeric characters
- PascalCase the result
- Example: "My Cool App" becomes `MyCoolApp`

The prefix is used for all local SPM targets to **avoid name collisions** with ios-libs targets:
- `{PREFIX}App` — main app target
- `{PREFIX}Bridge` — bridge target wrapping SharedKit
- `{PREFIX}APIClient` — API client target (if API selected)

Present to the user for confirmation:

> App prefix derived: **{PREFIX}**
> Targets will be named: `{PREFIX}App`, `{PREFIX}Bridge`{, `{PREFIX}APIClient` if API selected}
>
> Does this look right, or would you prefer a different prefix?

Proceed on confirmation, or update `PREFIX` if the user provides an alternative.

## Step 5: Create Directory Structure

```bash
mkdir -p "$TARGET_PATH/Sources/${PREFIX}App/Configuration"
mkdir -p "$TARGET_PATH/Sources/${PREFIX}Bridge"
```

If API_STRATEGY is not "None":
```bash
mkdir -p "$TARGET_PATH/Sources/${PREFIX}APIClient"
```

## Step 6: Generate Package.swift

Write `$TARGET_PATH/Package.swift` using the Write tool. Adapt the template based on Q&A answers:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "{APP_NAME}",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/gioe/ios-libs.git", branch: "main")
    ],
    targets: [
        .target(
            name: "{PREFIX}App",
            dependencies: [
                "{PREFIX}Bridge",
                // Include "{PREFIX}APIClient" only if API_STRATEGY is not "None"
            ]
        ),
        .target(
            name: "{PREFIX}Bridge",
            dependencies: [
                .product(name: "SharedKit", package: "ios-libs")
            ]
        ),
        // Include this target only if API_STRATEGY is not "None":
        .target(
            name: "{PREFIX}APIClient",
            dependencies: [
                .product(name: "APIClient", package: "ios-libs")
            ]
        ),
    ]
)
```

**Rules:**
- Omit `{PREFIX}APIClient` target and its dependency in `{PREFIX}App` entirely if API_STRATEGY is "None"
- Always include `{PREFIX}Bridge` — it prevents SwiftUI View extension symbol leaks

## Step 7: Generate App Entry Point and ContentView

### {PREFIX}App.swift

Write to `$TARGET_PATH/Sources/{PREFIX}App/{PREFIX}App.swift`:

The generated App struct must:
1. Import `SwiftUI` and `{PREFIX}Bridge`
2. Import `{PREFIX}APIClient` (if API selected)
3. Set up `ServiceContainer` with selected features via `configureServices()`
4. Set up `APIClientFactory` (if API selected)
5. Set up `NavigationCoordinator<AppRoute>` (if coordinator nav selected)
6. Inject environment values at the root

**Template (adapt based on selections):**

```swift
import SwiftUI
import {PREFIX}Bridge
// import {PREFIX}APIClient — only if API_STRATEGY is not "None"

@main
struct {PREFIX}App: App {
    // Only if NAV_PATTERN is "CoordinatedNavigationStack":
    @StateObject private var coordinator = NavigationCoordinator<AppRoute>()

    private let container: ServiceContainer
    // Only if API_STRATEGY is not "None":
    private let apiClientFactory: APIClientFactory

    init() {
        let container = ServiceContainer()
        ServiceRegistration.configure(container)
        self.container = container

        // Only if API_STRATEGY is not "None":
        self.apiClientFactory = APIClientFactory(
            serverURL: AppConfiguration.apiBaseURL
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.appTheme, DefaultTheme())
                .environment(\.serviceContainer, container)
                // Only if NAV_PATTERN is "CoordinatedNavigationStack":
                .navigationCoordinator(coordinator)
        }
    }
}
```

**Important:** The `{PREFIX}Bridge` module re-exports the SharedKit types needed by the app (DefaultTheme, ServiceContainer, NavigationCoordinator, etc.), so the app target imports `{PREFIX}Bridge`, NOT `SharedKit` directly.

### ContentView.swift

Write to `$TARGET_PATH/Sources/{PREFIX}App/ContentView.swift`:

**If NAV_PATTERN is "CoordinatedNavigationStack":**
```swift
import SwiftUI
import {PREFIX}Bridge

struct ContentView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator<AppRoute>

    var body: some View {
        CoordinatedNavigationStack(coordinator: coordinator) { route in
            switch route {
            case .home:
                HomeView()
            case .settings:
                SettingsView()
            }
        } root: {
            HomeView()
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var coordinator: NavigationCoordinator<AppRoute>

    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to {APP_NAME}")
                .font(.largeTitle)
            Button("Settings") {
                coordinator.push(.settings)
            }
        }
        .navigationTitle("{APP_NAME}")
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .navigationTitle("Settings")
    }
}
```

**If NAV_PATTERN is "TabView + NavigationStack":**
```swift
import SwiftUI
import {PREFIX}Bridge

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "house") }

            NavigationStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gear") }
        }
    }
}

struct HomeView: View {
    var body: some View {
        Text("Welcome to {APP_NAME}")
            .font(.largeTitle)
            .navigationTitle("{APP_NAME}")
    }
}

struct SettingsView: View {
    var body: some View {
        Text("Settings")
            .navigationTitle("Settings")
    }
}
```

**If NAV_PATTERN is "Simple NavigationStack":**
```swift
import SwiftUI
import {PREFIX}Bridge

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HomeView()
        }
    }
}

struct HomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Welcome to {APP_NAME}")
                .font(.largeTitle)
        }
        .navigationTitle("{APP_NAME}")
    }
}
```

## Step 8: Generate AppRoute (Conditional)

**Only if NAV_PATTERN is "CoordinatedNavigationStack".**

Write to `$TARGET_PATH/Sources/{PREFIX}App/AppRoute.swift`:

```swift
import Foundation

enum AppRoute: Hashable {
    case home
    case settings
}
```

## Step 9: Generate Configuration Files (Conditional)

### AppConfiguration.swift

**Only if API_STRATEGY is not "None".**

Write to `$TARGET_PATH/Sources/{PREFIX}App/Configuration/AppConfiguration.swift`:

```swift
import Foundation

enum AppConfiguration {
    /// Base URL for the API backend.
    /// Update this to point to your actual server.
    static let apiBaseURL = URL(string: "https://api.example.com")!

    /// Bundle identifier
    static let bundleID = "{BUNDLE_ID_PREFIX}.{APP_NAME_LOWERCASE}"
}
```

### ServiceRegistration.swift

**Only if SELECTED_FEATURES is non-empty.**

Write to `$TARGET_PATH/Sources/{PREFIX}App/Configuration/ServiceRegistration.swift`:

```swift
import {PREFIX}Bridge

enum ServiceRegistration {
    static func configure(_ container: ServiceContainer) {
        // Register only the features selected during scaffold:
    }
}
```

Inside `configure(_:)`, add registrations **only** for selected features. Use this mapping:

| Feature | Registration |
|---------|-------------|
| NetworkMonitor | `container.register(NetworkMonitorProtocol.self, scope: .appLevel) { NetworkMonitor.shared }` |
| KeychainStorage | `container.register(SecureStorageProtocol.self, scope: .appLevel) { KeychainStorage() }` |
| BiometricAuth | `container.register(BiometricAuthManager.self, scope: .appLevel) { BiometricAuthManager() }` |
| ToastManager | `container.register(ToastManagerProtocol.self, scope: .featureLevel) { ToastManager() }` |
| HapticManager | `container.register(HapticManager.self, scope: .appLevel) { HapticManager() }` |
| OfflineOperationQueue | `container.register(OfflineOperationQueue.self, scope: .appLevel) { OfflineOperationQueue() }` |
| DataCache + ImageCache | `container.register(DataCache.self, scope: .appLevel) { DataCache() }` and `container.register(ImageCache.self, scope: .appLevel) { ImageCache() }` |
| AppStateStorage | `container.register(AppStateStorageProtocol.self, scope: .appLevel) { AppStateStorage() }` |

If SELECTED_FEATURES is empty, skip this file entirely and remove the `ServiceRegistration.configure(container)` call from App.swift.

## Step 10: Generate Bridge Target

Write to `$TARGET_PATH/Sources/{PREFIX}Bridge/{PREFIX}Bridge.swift`:

The bridge target prevents SwiftUI View extension symbol leaks (see ios-libs CLAUDE.md). It uses `@_implementationOnly import SharedKit` and re-exports only the types the app needs.

```swift
@_implementationOnly import SharedKit
import SwiftUI

// MARK: - Re-exported Types
// The bridge target hides SharedKit's SwiftUI View extensions from the app target,
// preventing "ambiguous use of" errors when the app defines its own View extensions.

// Theme
public typealias AppThemeProtocol = SharedKit.AppThemeProtocol
public typealias DefaultTheme = SharedKit.DefaultTheme

// Service Container
public typealias ServiceContainer = SharedKit.ServiceContainer
public typealias ServiceScope = SharedKit.ServiceScope
```

**Add re-exports based on selections:**

If NAV_PATTERN uses coordinator (do NOT re-export `AppRoute` — it is defined locally in the app target):
```swift
// Navigation
public typealias NavigationCoordinator = SharedKit.NavigationCoordinator
public typealias CoordinatedNavigationStack = SharedKit.CoordinatedNavigationStack
public typealias ModalPresentation = SharedKit.ModalPresentation
public typealias PresentationStyle = SharedKit.PresentationStyle
```

For each SELECTED_FEATURE, add the corresponding re-export:

| Feature | Re-export |
|---------|-----------|
| NetworkMonitor | `public typealias NetworkMonitor = SharedKit.NetworkMonitor` and `public typealias NetworkMonitorProtocol = SharedKit.NetworkMonitorProtocol` |
| KeychainStorage | `public typealias KeychainStorage = SharedKit.KeychainStorage` and `public typealias SecureStorageProtocol = SharedKit.SecureStorageProtocol` |
| BiometricAuth | `public typealias BiometricAuthManager = SharedKit.BiometricAuthManager` |
| ToastManager | `public typealias ToastManager = SharedKit.ToastManager` and `public typealias ToastManagerProtocol = SharedKit.ToastManagerProtocol` |
| HapticManager | `public typealias HapticManager = SharedKit.HapticManager` |
| OfflineOperationQueue | `public typealias OfflineOperationQueue = SharedKit.OfflineOperationQueue` |
| DataCache + ImageCache | `public typealias DataCache = SharedKit.DataCache` and `public typealias ImageCache = SharedKit.ImageCache` |
| AppStateStorage | `public typealias AppStateStorage = SharedKit.AppStateStorage` and `public typealias AppStateStorageProtocol = SharedKit.AppStateStorageProtocol` |

Also re-export the environment key extensions so the app target can use `.environment(\.appTheme, ...)` and `.environment(\.serviceContainer, ...)`:
```swift
// Environment extensions are automatically available through the re-exported types.
// The .environment(\.appTheme, ...) and .environment(\.serviceContainer, ...) modifiers
// work because EnvironmentValues extensions are resolved at the SwiftUI framework level,
// not through the import that declares the key.
```

**Important note on `@_implementationOnly`:** This attribute prevents SharedKit's public symbols from leaking through the bridge module's public interface. However, `public typealias` declarations explicitly re-export chosen symbols. The net effect: only the types listed as typealiases are visible to the app target — all other SharedKit symbols (including View extensions) stay hidden.

## Step 11: Generate APIClient Target (Conditional)

**Only if API_STRATEGY is not "None".**

### {PREFIX}APIClient.swift

Write to `$TARGET_PATH/Sources/{PREFIX}APIClient/{PREFIX}APIClient.swift`:

```swift
import APIClient

// MARK: - Re-exported API Types

/// Re-export APIClientFactory so the app target can initialize it.
public typealias APIClientFactory = APIClient.APIClientFactory
public typealias AuthenticationMiddleware = APIClient.AuthenticationMiddleware
public typealias LoggingMiddleware = APIClient.LoggingMiddleware
public typealias RetryMiddleware = APIClient.RetryMiddleware

// Add product-specific extensions on generated types here.
// Example:
// extension Components.Schemas.User {
//     var displayName: String { "\(firstName) \(lastName)" }
// }
```

### openapi.json (placeholder)

**Only if API_STRATEGY is "OpenAPI Generated".**

Write to `$TARGET_PATH/Sources/{PREFIX}APIClient/openapi.json`:

```json
{
  "openapi": "3.1.0",
  "info": {
    "title": "{APP_NAME} API",
    "version": "0.1.0"
  },
  "paths": {},
  "components": {
    "schemas": {}
  }
}
```

### openapi-generator-config.yaml

**Only if API_STRATEGY is "OpenAPI Generated".**

Write to `$TARGET_PATH/Sources/{PREFIX}APIClient/openapi-generator-config.yaml`:

```yaml
generate:
  - types
  - client
accessModifier: public
namingStrategy: idiomatic
```

## Step 12: Generate Consumer CLAUDE.md

Write to `$TARGET_PATH/CLAUDE.md`:

````markdown
# CLAUDE.md

## Commands

```bash
swift build                        # Build all targets
swift build --target {PREFIX}App   # Build app target only
swift build --target {PREFIX}Bridge # Build bridge target only
```

## Architecture

This project uses [ios-libs](https://github.com/gioe/ios-libs) for shared infrastructure.

### Targets

- **{PREFIX}App** — Main app target. Imports `{PREFIX}Bridge` (not SharedKit directly).
- **{PREFIX}Bridge** — Bridge target that wraps ios-libs SharedKit. Uses `@_implementationOnly import SharedKit` to prevent View extension symbol leaks. Add new SharedKit type re-exports here when needed.
{IF_API}- **{PREFIX}APIClient** — API client target wrapping ios-libs APIClient. Add product-specific type extensions here.{/IF_API}

### Why a Bridge Target?

ios-libs SharedKit defines SwiftUI View extensions (typography helpers, design system modifiers) that collide with identically-named extensions in consumer apps. Linking both SharedKit and the app target causes "ambiguous use of" errors. The bridge target uses `@_implementationOnly import` to hide these extensions while re-exporting only the types you need.

### ios-libs Features Integrated

{List the SELECTED_FEATURES and API/Auth choices made during scaffold}

### Adding New SharedKit Types

When you need a new type from SharedKit in your app:
1. Open `Sources/{PREFIX}Bridge/{PREFIX}Bridge.swift`
2. Add a `public typealias` for the type
3. Import from `{PREFIX}Bridge` in your app code — never import SharedKit directly in `{PREFIX}App`

### Before Creating New Components

Check ios-libs SharedKit first — it may already have what you need:
- Design tokens: `DesignSystem`, `ColorPalette`, `Typography`
- Services: `BiometricAuthManager`, `KeychainStorage`, `NetworkMonitor`, `ToastManager`, etc.
- Navigation: `NavigationCoordinator`, `CoordinatedNavigationStack`, `DeepLinkHandler`
- Architecture: `BaseViewModel`, `ServiceContainer`, `@Injected`

If you build something generic, consider proposing extraction via `/extract-to-libs`.
````

Adapt the template:
- Include the `{PREFIX}APIClient` section only if API was selected
- List the actual features selected in the "Features Integrated" section
- Remove coordinator/navigation references if Simple NavigationStack was chosen

## Step 13: Verify Compilation

Run `swift build` in the target directory:

```bash
cd "$TARGET_PATH" && swift build 2>&1
```

Use a **300-second timeout** — first build resolves the ios-libs dependency from GitHub.

**If the build succeeds:** proceed to Step 14.

**If the build fails:**
1. Read the full error output
2. Identify the issue — common failures:
   - Missing type re-export in bridge target → add the typealias
   - Target name mismatch in Package.swift → fix the name
   - Import statement referencing wrong module → fix the import
3. Apply the fix using the Edit tool
4. Retry `swift build` once
5. If it still fails, present the error to the user and ask for guidance — do not loop further

## Step 14: Summary

After successful compilation, present a summary:

```markdown
## Scaffold Complete

**Project:** {APP_NAME}
**Location:** {TARGET_PATH}
**Bundle ID:** {BUNDLE_ID_PREFIX}.{app_name_lowercase}

### Generated Files

| File | Purpose |
|------|---------|
| `Package.swift` | SPM manifest with ios-libs dependency |
| `Sources/{PREFIX}App/{PREFIX}App.swift` | App entry point with environment injection |
| `Sources/{PREFIX}App/ContentView.swift` | Root view with {NAV_PATTERN} |
| ... | (list all generated files) |
| `CLAUDE.md` | Project guidance for Claude Code |

### Next Steps

1. Replace the placeholder API URL in `AppConfiguration.swift` with your backend URL
2. Replace `openapi.json` with your backend's OpenAPI spec (if using OpenAPI)
3. Run `swift build` to regenerate API types from your spec
4. Start building features — use `BaseViewModel` from SharedKit as your ViewModel base class
```

Adapt the summary based on which files were actually generated.
