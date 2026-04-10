---
name: xcode-file-manager
description: Add or remove Swift files in an Xcode project. Supports both xcodegen-based projects (regenerate from project.yml) and manual xcodeproj projects (Ruby script or direct pbxproj editing). Use when creating or deleting Swift files that need to be reflected in the Xcode project.
allowed-tools: Bash, Read, Write, Glob
---

# Xcode File Manager Skill

This skill handles adding and removing Swift files in an Xcode project.

## When to Use This Skill

Use this skill whenever you:
- Create a new Swift file that needs to be part of an Xcode build target
- Delete a Swift file and need to remove it from the Xcode project
- Need to verify files are correctly registered in the project

## Step 1: Detect the project management approach

Check the project directory for how the `.xcodeproj` is managed:

```bash
ls "$PROJECT_DIR"/project.yml 2>/dev/null   # xcodegen
ls "$PROJECT_DIR"/scripts/add_files_to_xcode.rb 2>/dev/null   # Ruby script
```

| Found | Approach |
|-------|----------|
| `project.yml` | **xcodegen** — files are auto-discovered from source directories. Just create the file on disk and regenerate. |
| `scripts/add_files_to_xcode.rb` | **Ruby script** — use the script to add files to `project.pbxproj`. |
| Neither | **Manual** — edit `project.pbxproj` directly (last resort). |

## Approach A: xcodegen Projects

With xcodegen, the `.xcodeproj` is generated from `project.yml`. Files are discovered automatically from the `sources` paths defined in the YAML.

### Adding files

1. Create the Swift file on disk in the appropriate source directory
2. Verify the directory is covered by a `sources` entry in `project.yml`
3. Regenerate the project:

```bash
cd "$PROJECT_DIR" && xcodegen generate
```

### Removing files

1. Delete the file from disk
2. Regenerate the project:

```bash
cd "$PROJECT_DIR" && xcodegen generate
```

### Adding a new source directory

If the file goes in a directory not yet listed in `project.yml`, add it:

```yaml
targets:
  MyApp:
    sources:
      - path: Sources/MyApp
      - path: Sources/NewModule  # Add this
```

Then regenerate.

## Approach B: Ruby Script Projects

Use the existing Ruby scripts to manipulate `project.pbxproj`.

### Prerequisites

```bash
gem install xcodeproj
```

### Adding files

```bash
cd "$PROJECT_DIR" && ruby scripts/add_files_to_xcode.rb <relative_path_to_file>
```

**Examples:**

```bash
# Add a single file
ruby scripts/add_files_to_xcode.rb App/ViewModels/NewViewModel.swift

# Add multiple files
ruby scripts/add_files_to_xcode.rb App/Views/NewView.swift App/ViewModels/NewViewModel.swift

# Add a test file (automatically added to test target)
ruby scripts/add_files_to_xcode.rb AppTests/NewTests.swift
```

### Path conventions

- Paths must be relative to the project directory (where the `.xcodeproj` lives)
- The script uses the directory structure to find the correct Xcode group
- Files are added to the target whose name matches the top-level directory

### Creating new groups first

If the target group doesn't exist in the Xcode project, use `/xcode-group-manager` first:

```bash
# Step 1: Create the missing group
ruby scripts/manage_xcode_groups.rb --create-group App/Features/Auth/Views

# Step 2: Then add the file
ruby scripts/add_files_to_xcode.rb App/Features/Auth/Views/LoginView.swift
```

> **Why:** If the group is missing, the add script may place the file under the root group with an incorrect path, causing "Build input files cannot be found" errors.

### Verifying path attributes

After adding files in nested groups, verify the `PBXFileReference` in `project.pbxproj` uses the full relative path — not just the filename. Compare against sibling files in the same group.

### Removing files

```bash
cd "$PROJECT_DIR" && ruby scripts/remove_files_from_xcode.rb <relative_path_to_file>
```

**Options:**

| Flag | Effect |
|------|--------|
| *(none)* | Remove from project and delete from disk |
| `--keep-files` | Remove from project only; file stays on disk |

> **Warning:** Disk deletion is permanent. Ensure the file is committed to git first.

> **Note:** The remove script does not stage git changes. Stage manually before committing.

## Approach C: Manual (Last Resort)

If neither xcodegen nor Ruby scripts are available, files must be added to `project.pbxproj` manually. This is error-prone — prefer installing the `xcodeproj` gem or adding xcodegen support.

## Troubleshooting

- **"Group not found"**: Use `/xcode-group-manager` to create the group first
- **"File already in project"**: The reference already exists; skip unless the path is wrong
- **"Build input files cannot be found"**: File was added to the wrong group; remove, create correct group, re-add
- **xcodegen not picking up new files**: Verify the source directory is listed in `project.yml`

## Related Skills

- `/xcode-group-manager`: Create or remove Xcode group hierarchies
- `/build-ios-project`: Build the project to verify changes compile
