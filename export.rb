#!/usr/bin/env ruby

require_relative 'lib/obsidian_daily_exporter'
require_relative 'lib/markdown_concatenator'

# Configuration from environment
VAULT_PATH = ENV['OBSIDIAN_VAULT']
DAYS_BACK = ENV.fetch('DAYS_BACK', '7').to_i
EXPORT_BASE = ENV.fetch('EXPORT_BASE', '/tmp')

if VAULT_PATH.nil? || VAULT_PATH.empty?
  puts "❌ Error: OBSIDIAN_VAULT environment variable must be set"
  puts "Usage: OBSIDIAN_VAULT=/path/to/vault ruby export.rb"
  exit 1
end

# Run the exporter
exporter = ObsidianDailyExporter.new(
  vault_path: VAULT_PATH,
  days_back: DAYS_BACK,
  export_base: EXPORT_BASE
)

result = exporter.run

# Automatically concatenate exported files to XML
puts "\n🔄 Creating XML export..."
concatenator = MarkdownConcatenator.new(export_dir: result[:export_dir])
xml_file = concatenator.run

puts "📦 Complete! Export available at: #{result[:export_dir]}"
puts "📄 XML file: #{xml_file}"