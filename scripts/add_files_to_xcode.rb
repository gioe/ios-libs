#!/usr/bin/env ruby
# Script to add files to an Xcode project
# Usage: ruby add_files_to_xcode.rb [--no-target] [--ascii] [--project <name.xcodeproj>] <file_path1> <file_path2> ...
# Example: ruby add_files_to_xcode.rb MyApp/ViewModels/MyViewModel.swift
# Example: ruby add_files_to_xcode.rb --no-target MyApp/openapi.json

require 'xcodeproj'

# Parse options
no_target = ARGV.delete('--no-target')
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
  puts "Usage: ruby add_files_to_xcode.rb [--no-target] [--ascii] [--project <name.xcodeproj>] <file_path1> ..."
  puts "Example: ruby add_files_to_xcode.rb MyApp/ViewModels/MyViewModel.swift"
  puts ""
  puts "Options:"
  puts "  --no-target            Add file to project without adding to any build target"
  puts "  --ascii                Use ASCII status symbols (auto-detected in CI)"
  puts "  --project <path>       Path to .xcodeproj (auto-detected if omitted)"
  exit 1
end

# Change to the script's parent directory (expected: project root with .xcodeproj)
Dir.chdir(File.dirname(__FILE__) + '/..')

# Auto-detect .xcodeproj if not specified
if project_path.nil?
  candidates = Dir.glob('*.xcodeproj')
  if candidates.empty?
    puts "#{ERR} No .xcodeproj found in #{Dir.pwd}"
    exit 1
  end
  project_path = candidates.first
  puts "Auto-detected project: #{project_path}" if candidates.length > 1
end

unless File.exist?(project_path)
  puts "#{ERR} Could not find #{project_path}"
  exit 1
end

project = Xcodeproj::Project.open(project_path)

# Build a target lookup: map top-level directory names to targets
# Convention: files in "FooTests/" go to a target named "FooTests",
# files in "FooUITests/" go to "FooUITests", everything else goes to the main app target.
targets_by_name = {}
project.targets.each { |t| targets_by_name[t.name] = t }

# Find the main app target (type: application)
main_target = project.targets.find { |t| t.product_type == 'com.apple.product-type.application' }
main_target ||= project.targets.first

# Process each file
ARGV.each do |file_path|
  unless File.exist?(file_path)
    puts "#{ERR} File not found: #{file_path}"
    next
  end

  # Determine the group path from the file path
  path_parts = file_path.split('/')
  file_name = path_parts.pop

  # Find the appropriate group
  group = project.main_group
  path_parts.each do |part|
    existing_group = group[part]
    if existing_group.nil?
      puts "#{ERR} Group not found in project: #{path_parts.join('/')}"
      break
    end
    group = existing_group
  end

  # Check if file already exists in the group
  existing_file = group.files.find { |f| f.path == file_name }
  if existing_file
    puts "#{WARN} File already in project: #{file_path}"
    if existing_file.real_path.to_s != File.absolute_path(file_path)
      puts "  Removing incorrect reference..."
      existing_file.remove_from_project
    else
      next
    end
  end

  # Determine the file type based on extension
  file_type = case File.extname(file_name).downcase
  when '.swift' then 'sourcecode.swift'
  when '.json' then 'text.json'
  when '.yaml', '.yml' then 'text.yaml'
  when '.plist' then 'text.plist.xml'
  when '.md' then 'net.daringfireball.markdown'
  when '.h' then 'sourcecode.c.h'
  when '.m' then 'sourcecode.c.objc'
  when '.strings' then 'text.plist.strings'
  when '.storyboard' then 'file.storyboard'
  when '.xib' then 'file.xib'
  when '.xcassets' then 'folder.assetcatalog'
  else nil
  end

  # Add the file to the group with proper file type
  file_ref = group.new_reference(file_name)
  file_ref.last_known_file_type = file_type if file_type

  if no_target
    puts "#{OK} Added #{file_path} to project (no target)"
  else
    # Determine which target based on top-level directory name
    top_dir = path_parts.first
    target = targets_by_name[top_dir] || main_target
    target_name = target.name

    target.add_file_references([file_ref])
    puts "#{OK} Added #{file_path} to #{target_name} target"
  end
end

# Save the project
project.save
puts "#{OK} Project saved successfully"
