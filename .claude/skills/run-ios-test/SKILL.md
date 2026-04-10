---
name: run-ios-test
description: Run iOS tests for an Xcode or SPM project. Supports running all tests, a specific test class, or a specific test method. Detects project type and chooses xcodebuild or swift test accordingly.
allowed-tools: Bash
---

# Run iOS Test Skill

This skill runs iOS tests using `xcodebuild` or `swift test` depending on the project type.

## Usage

When this skill is invoked, determine what tests to run based on the user's request or context.

### Step 1: Detect xcpretty

```bash
which xcpretty
```

If it exits 0, use the xcpretty variant. Otherwise use raw output.

### Step 2: Detect the project type

Check the project directory (user-specified or current directory):

1. **`.xcodeproj` or `.xcworkspace`** — use `xcodebuild test`
2. **`Package.swift` only** — check platforms before choosing runner

For SPM packages, check if the package is iOS-only:

```bash
grep -A3 'platforms' Package.swift
```

- **iOS-only** (e.g., `.iOS(.v16)` with no `.macOS`): Must use `xcodebuild` with an `.xcodeproj`. If no `.xcodeproj` exists, check for `project.yml` and run `xcodegen generate` first.
- **macOS-compatible**: Use `swift test` (faster, no simulator needed).

### Step 3: Detect a simulator destination

For `xcodebuild`-based testing:

```bash
xcrun simctl list devices available | grep -E "iPhone" | head -5
```

### Step 4: Run tests

**All tests (xcodebuild):**

```bash
# With xcpretty — pipefail ensures test failures propagate
set -o pipefail && cd "$PROJECT_DIR" && xcodebuild test \
  -project <ProjectName>.xcodeproj \
  -scheme <SchemeName> \
  -destination 'platform=iOS Simulator,name=<SimName>,OS=<OSVersion>' \
  2>&1 | xcpretty

# Without xcpretty (fallback)
cd "$PROJECT_DIR" && xcodebuild test \
  -project <ProjectName>.xcodeproj \
  -scheme <SchemeName> \
  -destination 'platform=iOS Simulator,name=<SimName>,OS=<OSVersion>' \
  2>&1
```

**All tests (swift test):**

```bash
cd "$PROJECT_DIR" && swift test 2>&1
```

**Specific test class (xcodebuild):**

```bash
-only-testing:<TestTarget>/<TestClassName>
```

**Specific test method (xcodebuild):**

```bash
-only-testing:<TestTarget>/<TestClassName>/<testMethodName>
```

**Multiple test classes (xcodebuild):**

Chain multiple `-only-testing` flags.

**Specific test (swift test):**

```bash
cd "$PROJECT_DIR" && swift test --filter <TestClassName> 2>&1
cd "$PROJECT_DIR" && swift test --filter "<TestClassName>/testMethodName" 2>&1
```

## Arguments

When invoked with arguments, parse them to determine the test scope:

- **No arguments**: Run all tests
- **A class name** (e.g., `AuthManagerTests`): Run that test class
- **Class/method** (e.g., `AuthManagerTests/testLogin`): Run that specific test
- **A directory path**: Run tests for the project in that directory

### SPM class name detection

When given a class name, find where the test file lives:

```bash
find "$PROJECT_DIR" -name "<ClassName>.swift" 2>/dev/null | head -1
```

If it lives in an SPM package with macOS support, use `swift test --filter`. Otherwise use `xcodebuild -only-testing`.

## Interpreting Results

- **Test Succeeded**: All tests passed
- **Test Failed**: Check the output for failing test names and assertion failures
- **Build Failed**: Compilation errors prevent tests from running; fix build errors first

## Pre-existing Failure Check

When verifying that test failures are pre-existing (e.g., during `git stash` verification), run only the failing test class(es) instead of the full suite to keep the check fast:

```bash
# xcodebuild
-only-testing:<TestTarget>/<FailingTestClass>

# swift test
swift test --filter <FailingTestClass>
```

## Troubleshooting

### Simulator Not Found

```bash
xcrun simctl list devices available
```

### Tests Timeout

For long-running tests, add `-test-timeouts-enabled NO` or increase the timeout.

### xcodegen Projects

If the project uses xcodegen (`project.yml` exists), regenerate the `.xcodeproj` before testing:

```bash
cd "$PROJECT_DIR" && xcodegen generate
```

## Related Skills

- `/build-ios-project`: Build the project before running tests
- `/xcode-file-manager`: Manage files in the Xcode project
