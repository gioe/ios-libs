---
name: fastlane-upload-metadata
description: Upload App Store metadata (description, keywords, screenshots, review info) to App Store Connect without building or uploading a binary.
allowed-tools: Bash, Read
---

# Fastlane Upload Metadata Skill

This skill runs the fastlane `upload_metadata` lane to push metadata and screenshots to App Store Connect.

## What it does

- Uploads app name, subtitle, description, keywords, promotional text
- Uploads support/marketing/privacy URLs
- Uploads categories and review information
- Uploads screenshots for all device sizes

## Prerequisites

- An App Store Connect API key configured in the Fastfile
- Ruby with bundler installed
- Gems installed via `bundle install` in the iOS project directory
- A `Fastfile` with an `upload_metadata` lane defined

## Usage

Detect the iOS project directory:

```bash
find "$PROJECT_DIR" -name "Fastfile" -path "*/fastlane/*" | head -1
```

Then run:

```bash
cd "$IOS_DIR" && bundle exec fastlane upload_metadata 2>&1
```

If using Homebrew Ruby:

```bash
cd "$IOS_DIR" && export PATH="/opt/homebrew/opt/ruby/bin:/opt/homebrew/lib/ruby/gems/$(ruby -e 'puts RUBY_VERSION.split(".")[0..1].join(".")').0/bin:$PATH" && bundle exec fastlane upload_metadata 2>&1
```

**Timeout:** Use a 300000ms timeout.

## Interpreting results

- Look for `fastlane.tools finished successfully` at the end
- Screenshots that are already uploaded will show "Previous uploaded. Skipping"
- Precheck warnings are typically non-blocking

## Metadata file locations

All metadata typically lives in `fastlane/metadata/`:
- `en-US/name.txt` — App name (max 30 chars)
- `en-US/subtitle.txt` — Subtitle (max 30 chars)
- `en-US/description.txt` — Full description
- `en-US/keywords.txt` — Comma-separated keywords (max 100 chars)
- `en-US/promotional_text.txt` — Promotional text
- `en-US/release_notes.txt` — What's new
- `en-US/support_url.txt`, `marketing_url.txt`, `privacy_url.txt` — URLs
- `primary_category.txt`, `secondary_category.txt` — Categories (SCREAMING_CASE)
- `review_information/` — App review contact details

Screenshots live in `fastlane/screenshots/en-US/`.
