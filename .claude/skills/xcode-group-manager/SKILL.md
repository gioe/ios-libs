---
name: xcode-group-manager
description: Manage Xcode group hierarchies. Use when the target group for new Swift files does not yet exist in the Xcode project — run this before /xcode-file-manager to create the needed group path. Not needed for xcodegen projects (groups are auto-generated).
allowed-tools: Bash, Read
---

# Xcode Group Manager Skill

This skill creates or removes Xcode group hierarchies using the `xcodeproj` Ruby gem.

## When to Use This Skill

| Scenario | Skill to use |
|----------|-------------|
| **xcodegen project** (`project.yml` exists) | **Not needed** — xcodegen auto-creates groups from directory structure. Just create directories on disk and regenerate. |
| Group already exists, adding files to it | `/xcode-file-manager` only |
| Group does **not** exist yet (manual xcodeproj) | This skill first, then `/xcode-file-manager` |
| Removing an empty group | This skill |
| Removing files | `/xcode-file-manager` only |

## Prerequisites

```bash
gem install xcodeproj
```

A Ruby script `scripts/manage_xcode_groups.rb` must exist in the project directory.

## Detecting the approach

```bash
ls "$PROJECT_DIR"/project.yml 2>/dev/null
```

If `project.yml` exists, this skill is **not needed**. Simply:

```bash
mkdir -p "$PROJECT_DIR/Sources/NewModule"
cd "$PROJECT_DIR" && xcodegen generate
```

Otherwise proceed with the Ruby script approach below.

## Creating a Group Path

```bash
cd "$PROJECT_DIR" && ruby scripts/manage_xcode_groups.rb --create-group <group_path>
```

**Examples:**

```bash
# Create a nested feature group (all intermediate groups are created as needed)
ruby scripts/manage_xcode_groups.rb --create-group App/Features/Auth/Views
ruby scripts/manage_xcode_groups.rb --create-group App/Features/Auth/ViewModels

# Then add files using /xcode-file-manager
ruby scripts/add_files_to_xcode.rb App/Features/Auth/Views/LoginView.swift
```

- All missing intermediate groups are created automatically.
- Already-existing groups are left untouched (idempotent).

## Removing an Empty Group

```bash
cd "$PROJECT_DIR" && ruby scripts/manage_xcode_groups.rb --remove-group <group_path>
```

- Fails with an error if the group still has children (files or subgroups).
- No-ops silently if the group no longer exists.

## Typical Workflow: Adding Files to a New Feature Module

```bash
# 1. Create group hierarchy
ruby scripts/manage_xcode_groups.rb --create-group App/Features/Auth/Views
ruby scripts/manage_xcode_groups.rb --create-group App/Features/Auth/ViewModels

# 2. Create the Swift files on disk

# 3. Add files to the Xcode project and build target
ruby scripts/add_files_to_xcode.rb \
  App/Features/Auth/Views/LoginView.swift \
  App/Features/Auth/ViewModels/LoginViewModel.swift
```

## Troubleshooting

- **`[ERROR] Group not found`** when running `add_files_to_xcode.rb`: The group doesn't exist — use this skill to create it first.
- **`[ERROR] Group is not empty`** when removing: Remove or move all files first using `/xcode-file-manager`.
- **Build failure "Build input files cannot be found"**: A file was added to the wrong group. Remove the misplaced reference with `/xcode-file-manager --keep-files`, create the correct group, then re-add.
