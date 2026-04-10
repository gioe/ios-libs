---
name: build-ios-project
description: Build an iOS Xcode project to verify compilation succeeds. Detects project type (xcodeproj, xcworkspace, or SPM) and builds accordingly. Use to confirm code changes compile correctly before running tests or committing.
allowed-tools: Bash
---

# Build iOS Project Skill

This skill builds an iOS project using `xcodebuild` or `swift build` to verify that the project compiles successfully.

## Usage

When this skill is invoked, build the iOS project to verify compilation.

### Step 1: Detect the project type

Locate the project root. If the user specifies a directory, use it. Otherwise use the current working directory or the repo root.

```bash
PROJECT_DIR="${1:-.}"
```

Detect what kind of project it is (check in order):

1. **`.xcworkspace`** — use `xcodebuild -workspace`
2. **`.xcodeproj`** — use `xcodebuild -project`
3. **`Package.swift` only** — use `swift build`

```bash
ls "$PROJECT_DIR"/*.xcworkspace 2>/dev/null | head -1
ls "$PROJECT_DIR"/*.xcodeproj 2>/dev/null | head -1
ls "$PROJECT_DIR"/Package.swift 2>/dev/null
```

If a `project.yml` exists but no `.xcodeproj`, generate it first:

```bash
which xcodegen && cd "$PROJECT_DIR" && xcodegen generate
```

### Step 2: Detect xcpretty

```bash
which xcpretty
```

If it exits 0, use the xcpretty variant. Otherwise use raw `xcodebuild` output.

### Step 3: Detect a simulator destination

```bash
xcrun simctl list devices available | grep -E "iPhone|iPad" | head -5
```

Pick the first available iPhone simulator. Extract the name and OS version.

### Step 4: Build

**For `.xcodeproj` / `.xcworkspace`:**

```bash
# With xcpretty — pipefail ensures build failures propagate
set -o pipefail && cd "$PROJECT_DIR" && xcodebuild build \
  -project <ProjectName>.xcodeproj \
  -scheme <SchemeName> \
  -destination 'platform=iOS Simulator,name=<SimName>,OS=<OSVersion>' \
  2>&1 | xcpretty

# Without xcpretty (fallback)
cd "$PROJECT_DIR" && xcodebuild build \
  -project <ProjectName>.xcodeproj \
  -scheme <SchemeName> \
  -destination 'platform=iOS Simulator,name=<SimName>,OS=<OSVersion>' \
  2>&1
```

For workspaces, replace `-project` with `-workspace`.

**For SPM (`Package.swift` only):**

```bash
cd "$PROJECT_DIR" && swift build 2>&1
```

### Build for Release (Optional)

If specifically requested, add `-configuration Release`.

### Clean Build (Optional)

If a clean build is requested or there are stale build artifacts, replace `build` with `clean build`.

## Arguments

When invoked with arguments, parse them to determine the build type:

- **No arguments or a directory path**: Standard debug build
- **`clean`**: Clean and rebuild
- **`release`**: Build in Release configuration
- **`clean release`**: Clean and rebuild in Release configuration

## Interpreting Results

- **Build Succeeded**: The project compiles without errors
- **Build Failed**: Check the output for:
  - Compilation errors (syntax errors, type mismatches)
  - Linker errors (missing symbols, duplicate symbols)
  - Missing dependencies or frameworks

### Common Build Errors

| Error Type | Cause | Solution |
|------------|-------|----------|
| `Cannot find type 'X'` | Missing import or type not defined | Add import or check spelling |
| `Value of type 'X' has no member 'Y'` | Property/method doesn't exist | Verify API or add the member |
| `Missing argument for parameter` | Function call missing required params | Add missing arguments |
| `Cannot convert value` | Type mismatch | Check types and add conversion |
| `Undefined symbol` | Linker can't find implementation | Ensure file is added to target |

## Troubleshooting

### Simulator Not Found

List available simulators and adjust the `-destination`:

```bash
xcrun simctl list devices available
```

### Derived Data Issues

If builds fail with caching issues:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/<ProjectName>-*
```

### xcodegen Projects

If the project uses xcodegen (`project.yml` exists), regenerate the `.xcodeproj` before building:

```bash
cd "$PROJECT_DIR" && xcodegen generate
```

## Related Skills

- `/run-ios-test`: Run the test suite after confirming the build succeeds
- `/xcode-file-manager`: Add new Swift files to the Xcode project
