---
name: fastlane-submit-review
description: Submit the current App Store Connect build for App Store review with metadata and screenshots. Does not build or upload a new binary — uses whichever build is already processed on App Store Connect.
allowed-tools: Bash, Read
---

# Fastlane Submit Review Skill

This skill runs the fastlane `submit_review` lane to submit an app for App Store review.

## What it does

- Uploads latest metadata and screenshots
- Submits the current build for App Store review
- Sets IDFA usage to false (configurable in Fastfile)

**Important:** This submits the app for Apple review. Always confirm with the user before running.

## Prerequisites

- A binary must already be uploaded and processed on App Store Connect
- App Privacy section must be completed in App Store Connect
- All required screenshots must be uploaded
- A `Fastfile` with a `submit_review` lane defined

## Usage

Detect the iOS project directory:

```bash
find "$PROJECT_DIR" -name "Fastfile" -path "*/fastlane/*" | head -1
```

Then run:

```bash
cd "$IOS_DIR" && bundle exec fastlane submit_review 2>&1
```

If using Homebrew Ruby:

```bash
cd "$IOS_DIR" && export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/$(ruby -e 'puts RUBY_VERSION.split(".")[0..1].join(".")').0/bin:$PATH" && bundle exec fastlane submit_review 2>&1
```

**Timeout:** Use a 300000ms timeout.

## Interpreting results

- Look for `fastlane.tools finished successfully` at the end
- If it fails, common causes:
  - No processed build on App Store Connect
  - Missing App Privacy information
  - Missing required screenshots for a device size
