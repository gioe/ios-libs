---
name: fastlane-beta
description: Build and upload an iOS app to TestFlight with metadata. Runs bump_build_number, build, upload_testflight, and upload_metadata via the fastlane beta lane.
allowed-tools: Bash, Read
---

# Fastlane Beta Skill

This skill runs the fastlane `beta` lane to build and upload an iOS app to TestFlight.

## What it does

1. Bumps the build number (fetches latest from App Store Connect + 1)
2. Builds the IPA with App Store signing
3. Uploads binary to TestFlight
4. Uploads metadata and screenshots to App Store Connect

## Prerequisites

- An App Store Connect API key configured in the Fastfile
- Ruby with bundler installed
- Gems installed via `bundle install` in the iOS project directory
- A `Fastfile` with a `beta` lane defined

## Usage

Detect the iOS project directory (look for `Fastfile` or `fastlane/` directory):

```bash
find "$PROJECT_DIR" -name "Fastfile" -path "*/fastlane/*" | head -1
```

Then run:

```bash
cd "$IOS_DIR" && bundle exec fastlane beta 2>&1
```

If using Homebrew Ruby:

```bash
cd "$IOS_DIR" && export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/$(ruby -e 'puts RUBY_VERSION.split(".")[0..1].join(".")').0/bin:$PATH" && bundle exec fastlane beta 2>&1
```

**Timeout:** This command takes 3-5 minutes. Use a 600000ms timeout.

## Interpreting results

- Look for `fastlane.tools finished successfully` at the end
- The build number and TestFlight upload status will be in the output
- Precheck warnings are typically non-blocking
- If it fails, check for signing issues, API key problems, or App Store Connect errors
