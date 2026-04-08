---
name: scaffold
description: Scaffold a greenfield iOS app project with ios-libs integration, or audit an existing project to recommend ios-libs adoption — interactive Q&A, file generation, and compilation verification
allowed-tools: Bash, Read, Write, Edit, Glob, Grep, AskUserQuestion
---

# Scaffold — iOS App Generator & Adoption Auditor

Two modes:
- **Greenfield** (default) — generates a compilable iOS app project pre-wired with ios-libs
- **Adopt** — audits an existing iOS project for hand-rolled equivalents of ios-libs services and produces a migration report

## Step 0: Parse Arguments and Detect Mode

The user provides arguments after `/scaffold`. Supported forms:

- `/scaffold /path/to/dir` — greenfield mode (create new project)
- `/scaffold --adopt /path/to/existing-project` — adopt mode (audit existing project)
- `/scaffold /path/to/dir` where the directory already contains a `Package.swift` or `*.xcodeproj` — **auto-detect adopt mode**

### Resolve the path

If no argument was provided, ask:

> Where should the project be created (or where is the existing project to audit)? Provide an absolute path or a path relative to this repo's root.

```bash
tusk path   # prints path to tasks.db; project root is its parent
```

If relative, prepend the project root. If absolute, use as-is. Store as `TARGET_PATH`.

### Determine mode

```bash
ls "$TARGET_PATH/Package.swift" 2>/dev/null || ls "$TARGET_PATH/"*.xcodeproj 2>/dev/null
```

- If `--adopt` flag was passed → **adopt mode** (jump to [Adopt Mode](#adopt-mode))
- If the directory contains `Package.swift` or `*.xcodeproj` → auto-detect adopt mode. Confirm with the user:

  > `$TARGET_PATH` already contains an iOS project. Would you like to:
  > 1. **Adopt** — audit for ios-libs migration opportunities
  > 2. **Overwrite** — scaffold a new greenfield project (will overwrite conflicting files)

  If the user picks Adopt → jump to [Adopt Mode](#adopt-mode). If Overwrite → continue with greenfield.

- Otherwise → **greenfield mode** (continue below)

### Greenfield path validation

```bash
ls "$TARGET_PATH" 2>/dev/null || mkdir -p "$TARGET_PATH"
```

If the directory exists and is non-empty (but not an iOS project), warn the user:

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

## Step 12: Generate Consumer CLAUDE.md (Dynamic)

This step dynamically generates an ios-libs guidance section by scanning the ios-libs source tree at runtime. This ensures the CLAUDE.md always reflects the current state of the library — new components, services, or middleware added to ios-libs will automatically appear in future scaffolds.

### Step 12a: Scan ios-libs Sources

Resolve the ios-libs project root:

```bash
IOS_LIBS_ROOT="$(dirname "$(tusk path)")"
```

Run these discovery commands and capture the output:

**SharedKit Components:**
```bash
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Components/" 2>/dev/null | sed 's/\.swift$//' | sort
```

**SharedKit Services:**
```bash
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Services/" 2>/dev/null | sed 's/\.swift$//' | sort
```

**SharedKit Design tokens:**
```bash
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Design/" 2>/dev/null | sed 's/\.swift$//' | sort
```

**SharedKit Architecture:**
```bash
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Architecture/" 2>/dev/null | sed 's/\.swift$//' | sort
```

**SharedKit Navigation:**
```bash
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Navigation/" 2>/dev/null | sed 's/\.swift$//' | sort
```

**SharedKit Utilities:**
```bash
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Utilities/" 2>/dev/null | sed 's/\.swift$//' | sort
```

**SharedKit Protocols:**
```bash
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Protocols/" 2>/dev/null | sed 's/\.swift$//' | sort
```

**APIClient Middleware:**
```bash
ls "$IOS_LIBS_ROOT/Sources/APIClient/Middleware/" 2>/dev/null | sed 's/\.swift$//' | sort
```

**APIClient top-level files (excluding GeneratedSources/):**
```bash
ls "$IOS_LIBS_ROOT/Sources/APIClient/"*.swift 2>/dev/null | xargs -I{} basename {} .swift | sort
```

Store all results — they will be formatted into the CLAUDE.md section below.

### Step 12b: Build and Write CLAUDE.md

If `$TARGET_PATH/CLAUDE.md` already exists, **append** to it (do not overwrite). Read the existing file first with the Read tool, then use the Write tool to write the original content plus the new section. If it does not exist, create a new file.

The generated content has two parts: a **static project header** (always written) and a **dynamic ios-libs catalog** (built from the scan).

#### Static project header

Always include this at the top of the CLAUDE.md (or at the top of the appended section if the file already existed):

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

### ios-libs Features Integrated

{List the SELECTED_FEATURES and API/Auth choices made during scaffold}
````

Adapt the static header:
- Include the `{PREFIX}APIClient` target bullet only if API was selected
- List the actual features selected in the "Features Integrated" section

#### Dynamic ios-libs catalog

Build this section entirely from the scan results in Step 12a. Format each category using the discovered file names. **Only include categories that returned results** (skip empty directories).

````markdown
---

## ios-libs Component Catalog

> **Before creating new UI components, services, or utilities, check this catalog.** ios-libs SharedKit and APIClient provide tested, reusable implementations. Using them avoids duplication and ensures consistency across consumer apps.

### UI Components (`SharedKit/Components/`)

{List each component discovered in the scan, one per line, as a bullet: `- ComponentName`}

### Services (`SharedKit/Services/`)

{List each service discovered in the scan, one per line, as a bullet: `- ServiceName`}

### Design System (`SharedKit/Design/`)

{List each design file discovered: `- FileName` — e.g. `ColorPalette`, `DesignSystem`, `Typography`, `Theme`}

### Architecture (`SharedKit/Architecture/`)

{List each architecture file: `- FileName` — e.g. `BaseViewModel`, `ViewModelProtocol`}

### Navigation (`SharedKit/Navigation/`)

{List each navigation file: `- FileName` — e.g. `NavigationCoordinator`, `CoordinatedNavigationStack`, `DeepLinkHandler`}

### Utilities (`SharedKit/Utilities/`)

{List each utility file: `- FileName` — e.g. `Validators`, `AnyCodable`, `DebugFlags`}

### Protocols (`SharedKit/Protocols/`)

{List each protocol file: `- FileName` — e.g. `AnalyticsProvider`, `ErrorRecorder`, `RetryableError`}

### APIClient Middleware (`APIClient/Middleware/`)

{List each middleware file: `- FileName` — e.g. `AuthenticationMiddleware`, `LoggingMiddleware`, `RetryMiddleware`}

### APIClient Core (`APIClient/`)

{List each top-level APIClient file: `- FileName` — e.g. `APIClientFactory`, `APIError`}
````

#### Usage rules section

Always append this after the catalog:

````markdown
## Usage Rules

1. **Check ios-libs first.** Before creating a new UI component, service, utility, or middleware, search the catalog above. If ios-libs has it, use it via the bridge target.
2. **Never import SharedKit directly in {PREFIX}App.** Always go through `{PREFIX}Bridge` to prevent View extension symbol collisions.
3. **Add new re-exports to the bridge when needed.** If you need a SharedKit type not yet exposed:
   1. Open `Sources/{PREFIX}Bridge/{PREFIX}Bridge.swift`
   2. Add `public typealias MyType = SharedKit.MyType`
   3. Import from `{PREFIX}Bridge` in your app code
{IF_API}4. **Extend generated API types in {PREFIX}APIClient.** Product-specific convenience methods (e.g., `displayName` on a User schema) belong in `Sources/{PREFIX}APIClient/`, not in the app target.{/IF_API}
````

#### Bridge target pattern section

Always append this:

````markdown
## Bridge Target Pattern

### What It Does

The bridge target (`{PREFIX}Bridge`) sits between your app and ios-libs SharedKit. It uses `@_implementationOnly import SharedKit` to hide SharedKit's internal symbols — especially SwiftUI View extensions — from leaking into your app target.

### When You Need It

You need a bridge target whenever:
- Your app defines **its own SwiftUI View extensions** (e.g., `.cardStyle()`, `.themed()`) that could collide with SharedKit's extensions of the same name
- You link **multiple SPM packages** that both extend SwiftUI View — the bridge isolates each package's extensions

### When You Don't Need It

If your app has **no custom View extensions** and only depends on ios-libs (no other extension-heavy packages), you could import SharedKit directly. However, keeping the bridge is recommended — it's zero-cost at runtime and protects against future collisions.

### How It Works

```
{PREFIX}App ──imports──▶ {PREFIX}Bridge ──@_implementationOnly import──▶ SharedKit
                         (public typealiases)
```

Only types listed as `public typealias` in the bridge are visible to the app. All other SharedKit symbols (View extensions, internal helpers) stay hidden.
````

#### Contribution guidance section

Always append this:

````markdown
## Contributing Back to ios-libs

If you build a component, service, or utility that is **generic enough to be reused across apps**, consider extracting it into ios-libs:

1. Run `/extract-to-libs` from the ios-libs working directory — it will audit your project for extraction candidates
2. Extraction candidates should be app-agnostic (no product-specific logic, no hardcoded config)
3. Good candidates: UI components, design tokens, networking utilities, storage abstractions, validation logic
4. Poor candidates: app-specific screens, product business logic, configuration tied to one backend
````

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

---

# Adopt Mode

Audits an existing iOS project for hand-rolled equivalents of ios-libs services, design system patterns, and architecture components. Produces a structured migration report and optionally creates tasks for each recommendation.

## Adopt Step 1: Resolve ios-libs Root

```bash
IOS_LIBS_ROOT="$(dirname "$(tusk path)")"
```

Store this — it's used to dynamically discover what ios-libs offers.

## Adopt Step 2: Discover ios-libs Capabilities

Scan the ios-libs source tree to build the current list of available services, components, and patterns. This ensures the audit reflects the latest state of the library.

```bash
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Services/" 2>/dev/null | sed 's/\.swift$//' | sort
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Components/" 2>/dev/null | sed 's/\.swift$//' | sort
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Design/" 2>/dev/null | sed 's/\.swift$//' | sort
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Architecture/" 2>/dev/null | sed 's/\.swift$//' | sort
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Navigation/" 2>/dev/null | sed 's/\.swift$//' | sort
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Utilities/" 2>/dev/null | sed 's/\.swift$//' | sort
ls "$IOS_LIBS_ROOT/Sources/SharedKit/Protocols/" 2>/dev/null | sed 's/\.swift$//' | sort
ls "$IOS_LIBS_ROOT/Sources/APIClient/Middleware/" 2>/dev/null | sed 's/\.swift$//' | sort
ls "$IOS_LIBS_ROOT/Sources/APIClient/"*.swift 2>/dev/null | xargs -I{} basename {} .swift | sort
```

Store the results — they define what ios-libs can replace.

## Adopt Step 3: Scan Consumer Project for Service Equivalents

Search the consumer project's Swift files for patterns that indicate hand-rolled implementations of ios-libs services. Use Grep with the consumer project path.

### Service Detection Patterns

For each ios-libs service, grep the consumer project for characteristic patterns. These patterns detect both exact name matches and common alternative implementations:

| ios-libs Service | Grep Patterns (any match = candidate) |
|-----------------|--------------------------------------|
| **NetworkMonitor** | `NWPathMonitor`, `class.*NetworkMonitor`, `protocol.*NetworkMonitor`, `Reachability` |
| **KeychainStorage** | `SecItemAdd`, `SecItemCopy`, `kSecClass`, `class.*Keychain`, `protocol.*SecureStorage` |
| **BiometricAuthManager** | `LAContext`, `evaluatePolicy`, `canEvaluatePolicy`, `class.*BiometricAuth` |
| **ToastManager** | `class.*Toast`, `protocol.*Toast`, `struct.*ToastData` |
| **HapticManager** | `UIImpactFeedbackGenerator`, `UINotificationFeedbackGenerator`, `class.*Haptic` |
| **OfflineOperationQueue** | `class.*OfflineQueue`, `class.*SyncQueue`, `class.*PendingOperation` |
| **DataCache** | `actor.*Cache`, `class.*DataCache`, `NSCache`, `protocol.*Cacheable` |
| **ImageCache** | `class.*ImageCache`, `class.*ImageLoader`, `URLCache.*image` |
| **AppStateStorage** | `class.*AppState.*Storage`, `@AppStorage`, `UserDefaults.*wrapper` |
| **ServiceContainer** | `class.*Container`, `class.*DI`, `protocol.*Resolver`, `@propertyWrapper.*Inject` |
| **BaseViewModel** | `class.*BaseViewModel`, `class.*ViewModel.*ObservableObject`, `protocol.*ViewModel.*isLoading` |
| **NavigationCoordinator** | `class.*Coordinator`, `protocol.*Coordinator`, `class.*Router`, `class.*Navigator` |
| **Validators** | `func.*validate.*email`, `func.*validate.*password`, `func.*isValid.*URL` |

Run each pattern against `.swift` files in the consumer project. For each match:
1. Record the file path and matched line
2. Read the surrounding context (20 lines) to confirm it's an actual implementation, not just a reference or import
3. Classify as **strong match** (full implementation found) or **weak match** (partial pattern, needs manual review)

```bash
# Example: detect NetworkMonitor equivalents
rg -l "NWPathMonitor|class\s+\w*NetworkMonitor|protocol\s+\w*NetworkMonitor|Reachability" --type swift "$TARGET_PATH"
```

Use the Grep tool (not bash rg) for all pattern matching.

## Adopt Step 4: Scan for Design System Opportunities

Search the consumer project for raw design literals that could be replaced with SharedKit design tokens.

### Color Literals

```
Color\(\s*red:|Color\(\s*#|UIColor\(\s*red:|\.init\(\s*red:
Color\.\w+\.opacity|Color\(\s*"
```

Exclude matches inside files named `*ColorPalette*`, `*Theme*`, `*DesignSystem*`, or `*Colors*` — those are the consumer's own design system (which itself is a replacement candidate).

### Font Literals

```
\.font\(\s*\.system\(|Font\.system\(|Font\.custom\(|UIFont\.\w+\(size:
```

Exclude matches inside files named `*Typography*`, `*FontStyle*`, or `*Theme*`.

### Spacing/Layout Literals

```
\.padding\(\s*\d+\)|spacing:\s*\d+[^.0-9]|cornerRadius:\s*\d+[^.0-9]
```

These indicate hardcoded values that could use `DesignSystem.Spacing`, `DesignSystem.CornerRadius`, etc.

### Assessment

For each category, report:
- **Count** of raw literals found
- **Sample** (3-5 representative matches with file paths)
- Whether the consumer has their **own design system** (centralized tokens) or uses scattered raw values

If the consumer already has a centralized design system, recommend **replacing it** with SharedKit's design tokens. If they use scattered raw values, the recommendation is stronger — SharedKit provides immediate consistency.

## Adopt Step 5: Check Existing SPM Dependencies

Read the consumer's `Package.swift` (or scan `*.xcodeproj/project.pbxproj` for SPM references) to detect:

1. **Already depends on ios-libs** — if so, note which products are imported and skip recommending what's already wired up
2. **Conflicting packages** — packages that provide overlapping functionality (e.g., `KeychainAccess`, `Reachability`, `Alamofire`). These need migration plans, not just additions.
3. **Name collisions** — if the consumer has local targets named `SharedKit` or `APIClient`, flag the need for renaming (per ios-libs CLAUDE.md consumer integration guidance)

```bash
cat "$TARGET_PATH/Package.swift" 2>/dev/null
```

If no Package.swift, check for Xcode project:
```bash
ls "$TARGET_PATH/"*.xcodeproj 2>/dev/null
```

## Adopt Step 6: Produce Structured Report

Compile all findings into a structured report. Present it to the user with this format:

````markdown
# ios-libs Adoption Report

**Project:** {TARGET_PATH}
**Scan date:** {today's date}

## Service Replacements

| Consumer Implementation | ios-libs Replacement | Confidence | Files Affected |
|------------------------|---------------------|-----------|---------------|
| `CustomNetworkMonitor` in `Services/NetworkMonitor.swift` | `SharedKit.NetworkMonitor` | Strong | 3 files import it |
| `KeychainWrapper` in `Utilities/Keychain.swift` | `SharedKit.KeychainStorage` | Strong | 5 files import it |
| ... | ... | ... | ... |

{For each row, include a brief explanation of what the consumer's implementation does and how it maps to the ios-libs equivalent.}

## Design System Opportunities

| Category | Raw Literals Found | Recommendation |
|----------|-------------------|----------------|
| Colors | 47 raw `Color(...)` across 12 files | Replace with `ColorPalette` tokens |
| Fonts | 23 raw `Font.system(...)` across 8 files | Replace with `Typography` scale |
| Spacing | 31 hardcoded padding values across 15 files | Replace with `DesignSystem.Spacing` tokens |

{Include 3-5 sample matches per category}

## Architecture Opportunities

{If the project has custom ViewModel base classes, navigation coordinators, or DI containers, list them here with the ios-libs equivalent.}

## Dependency Conflicts

{List any existing SPM dependencies that overlap with ios-libs functionality.}
- `KeychainAccess` → replace with `SharedKit.KeychainStorage`
- `Reachability` → replace with `SharedKit.NetworkMonitor`

## Integration Complexity

**Estimated effort:** {Low / Medium / High}

{Brief assessment based on:}
- Number of replacements needed
- Whether a bridge target is required (yes if consumer has View extensions)
- Whether SPM dependencies need migration
- Whether the consumer has their own design system (higher effort to migrate)

## Recommended Migration Order

{Ordered list from lowest-risk to highest-risk, with rationale:}
1. **Add ios-libs dependency** — add `ios-libs` to Package.swift, create bridge target
2. **Services** (one at a time) — replace hand-rolled services, each is self-contained
3. **Architecture** — adopt BaseViewModel as base class for ViewModels
4. **Design system** — replace raw literals with tokens (highest touch-count, do last)
````

## Adopt Step 7: Offer Task Creation

After presenting the report, ask the user:

> Would you like me to create migration tasks for these recommendations? Each replacement will become a separate task with acceptance criteria.

If the user accepts, create tasks by invoking `/create-task` with a structured description. Build the description from the report findings:

```
Migration tasks for ios-libs adoption in {project name}:

{For each service replacement:}
- Replace {consumer implementation} with ios-libs {replacement}
  Files: {list of affected files}
  Depends on: "Add ios-libs dependency to Package.swift" (if not already present)

{For design system migration:}
- Migrate raw Color literals to SharedKit ColorPalette tokens ({count} occurrences across {file_count} files)
  Depends on: "Add ios-libs dependency to Package.swift"
- Migrate raw Font literals to SharedKit Typography scale ({count} occurrences across {file_count} files)
  Depends on: "Migrate raw Color literals to SharedKit ColorPalette tokens"

{For architecture adoption:}
- Adopt SharedKit BaseViewModel as base class for ViewModels
  Depends on: "Add ios-libs dependency to Package.swift"
```

The `/create-task` skill handles decomposition, criteria generation, deduplication, and dependency wiring.

## Adopt Step 8: Generate Consumer CLAUDE.md

Append ios-libs guidance to the consumer project's CLAUDE.md, using the **same dynamic generation mechanism** as greenfield Step 12.

1. Check if `$TARGET_PATH/CLAUDE.md` exists
2. If it exists, read it first — append the ios-libs section
3. If it doesn't exist, create it

Use the same Step 12a scan (already done in Adopt Step 2) and Step 12b template, but adapt the static header:

- Skip the "Targets" section (the consumer's existing targets are their own)
- Skip the "Features Integrated" section (not applicable — this is an audit, not a scaffold)
- Include the full **ios-libs Component Catalog** (identical to greenfield)
- Include the **Usage Rules** section, adapted:
  - Replace `{PREFIX}Bridge` references with guidance to create a bridge target if one doesn't exist
  - Note: "If you haven't set up a bridge target yet, see the Bridge Target Pattern section below"
- Include the **Bridge Target Pattern** section (identical to greenfield, but with a generic `{AppName}Bridge` placeholder)
- Include the **Contributing Back** section (identical to greenfield)

Present the CLAUDE.md changes to the user before writing:

> I'll append an ios-libs guidance section to your project's CLAUDE.md. This includes a component catalog, usage rules, and bridge target instructions. Proceed?

## Adopt Step 9: Summary

Present a final summary:

````markdown
## Adoption Audit Complete

**Project:** {TARGET_PATH}

### Findings

- **{N} service replacements** identified (Strong: {n}, Weak: {n})
- **{N} design system opportunities** ({color_count} colors, {font_count} fonts, {spacing_count} spacing)
- **{N} architecture opportunities** identified
- **{N} dependency conflicts** to resolve

### Actions Taken

- [x] Scanned project for ios-libs equivalents
- [x] Produced adoption report
- {[x] Created {N} migration tasks | [ ] Task creation skipped}
- {[x] Appended ios-libs guidance to CLAUDE.md | [ ] CLAUDE.md update skipped}

### Next Steps

1. Review the migration tasks (if created) and prioritize based on your team's roadmap
2. Start with the lowest-risk replacement — typically a self-contained service like NetworkMonitor or KeychainStorage
3. Set up the bridge target before migrating any SharedKit components
4. Run `/extract-to-libs` if you find generic code worth contributing back
````
