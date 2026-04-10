---
name: fastlane-release
description: Full App Store release pipeline — captures screenshots, frames them, bumps build, builds IPA, uploads to TestFlight, and submits for App Store review via the fastlane release lane.
allowed-tools: Bash, Read
---

# Fastlane Release Skill

This skill runs the fastlane `release` lane for a full App Store submission.

## What it does

1. Captures App Store screenshots on all devices
2. Adds device frames and captions to screenshots
3. Bumps the build number
4. Builds the IPA with App Store signing
5. Uploads binary to TestFlight
6. Submits for App Store review (with metadata and screenshots)

## Prerequisites

- An App Store Connect API key configured in the Fastfile
- Ruby with bundler installed
- Gems installed via `bundle install` in the iOS project directory
- A `Fastfile` with a `release` lane defined
- iOS Simulator available for screenshot capture

## Usage

**Important:** This submits the app for App Store review. Confirm with the user before running.

Detect the iOS project directory:

```bash
find "$PROJECT_DIR" -name "Fastfile" -path "*/fastlane/*" | head -1
```

Then run:

```bash
cd "$IOS_DIR" && bundle exec fastlane release 2>&1
```

If using Homebrew Ruby:

```bash
cd "$IOS_DIR" && export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/$(ruby -e 'puts RUBY_VERSION.split(".")[0..1].join(".")').0/bin:$PATH" && bundle exec fastlane release 2>&1
```

**Timeout:** This command can take 10+ minutes due to screenshot capture. Use a 600000ms timeout.

## Interpreting results

- Look for `fastlane.tools finished successfully` at the end
- The app will be submitted for Apple review after completion
- Precheck warnings are typically non-blocking
