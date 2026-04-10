#!/usr/bin/env ruby
# Script to remove files from an Xcode project and optionally from disk
# Usage: ruby remove_files_from_xcode.rb [--keep-files] [--ascii] [--project <name.xcodeproj>] <file_path1> ...
# Example: ruby remove_files_from_xcode.rb MyApp/ViewModels/OldViewModel.swift
# Example: ruby remove_files_from_xcode.rb --keep-files MyApp/openapi.json

require 'xcodeproj'

# Parse options
keep_files = ARGV.delete('--keep-files')
ascii_mode = ARGV.delete('--ascii') || ENV['CI'] || ENV['TERM'] == 'dumb'

# Parse --project flag
project_path = nil
proj_idx = ARGV.index('--project')
if proj_idx
  ARGV.delete_at(proj_idx)
  project_path = ARGV.delete_at(proj_idx)
end

OK   = ascii_mode ? '[OK]'    : "\u2713"
ERR  = ascii_mode ? '[ERROR]' : "\u2717"
WARN = ascii_mode ? '[WARN]'  : "\u26A0"

if ARGV.empty?
  puts "Usage: ruby remove_files_from_xcode.rb [--keep-files] [--ascii] [--project <path>] <file_path1> ..."
  puts "Example: ruby remove_files_from_xcode.rb MyApp/ViewModels/OldViewModel.swift"
  puts ""
  puts "Options:"
  puts "  --keep-files       Remove from project but do not delete files from disk"
  puts "  --ascii            Use ASCII status symbols (auto-detected in CI)"
  puts "  --project <path>   Path to .xcodeproj (auto-detected if omitted)"
  exit 1
end

# Change to the script's parent directory
Dir.chdir(File.dirname(__FILE__) + '/..')

# Auto-detect .xcodeproj if not specified
if project_path.nil?
  candidates = Dir.glob('*.xcodeproj')
  if candidates.empty?
    puts "#{ERR} No .xcodeproj found in #{Dir.pwd}"
    exit 1
  end
  project_path = candidates.first
end

unless File.exist?(project_path)
  puts "#{ERR} Could not find #{project_path}"
  exit 1
end

project = Xcodeproj::Project.open(project_path)

failures = 0
any_removed = false

# Process each file
ARGV.each do |file_path|
  path_parts = file_path.split('/')
  file_name = path_parts.pop

  # Find the group containing the file
  group = project.main_group
  found = true
  path_parts.each do |part|
    existing_group = group[part]
    if existing_group.nil?
      puts "#{ERR} Group not found in project: #{path_parts.join('/')}"
      found = false
      failures += 1
      break
    end
    group = existing_group
  end
  next unless found

  # Find the file reference in the group
  file_ref = group.files.find { |f| f.path == file_name || File.basename(f.path.to_s) == file_name }
  if file_ref.nil?
    puts "#{ERR} File not found in project: #{file_path}"
    failures += 1
    next
  end

  # Collect ALL refs with this filename in the same group (handles duplicates)
  refs_in_group = group.files.select { |f| f.path == file_name || File.basename(f.path.to_s) == file_name }

  # Warn about refs with same name in other groups
  other_ref_count = project.objects.count do |obj|
    obj.is_a?(Xcodeproj::Project::Object::PBXFileReference) &&
      (obj.path == file_name || File.basename(obj.path.to_s) == file_name) &&
      !refs_in_group.include?(obj)
  end
  if other_ref_count > 0
    puts "#{WARN} #{other_ref_count} other reference(s) named '#{file_name}' exist at different group paths"
  end

  # Remove build-phase entries for all refs found in this group
  project.targets.each do |target|
    target.build_phases.each do |phase|
      phase.files.select { |bf| refs_in_group.include?(bf.file_ref) }.each do |build_file|
        build_file.remove_from_project
      end
    end
  end

  # Remove all file references in this group
  refs_in_group.each { |ref| ref.remove_from_project }
  any_removed = true

  # Delete from disk unless --keep-files was passed
  if keep_files
    puts "#{OK} Removed #{file_path} from project (file kept on disk)"
  elsif File.exist?(file_path)
    puts "Deleting from disk: #{file_path}"
    File.delete(file_path)
    puts "#{OK} Removed #{file_path} from project and deleted from disk"
  else
    puts "#{OK} Removed #{file_path} from project (file was not on disk)"
  end
end

if any_removed
  project.save
  puts "#{OK} Project saved successfully"
end

exit 1 if failures > 0
