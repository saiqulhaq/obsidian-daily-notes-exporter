# Quick Reference

## Installation

```bash
bundle install
```

## Running Scripts

### Export Daily Notes
```bash
OBSIDIAN_VAULT=/path/to/vault ruby export.rb

# With custom settings
OBSIDIAN_VAULT=/path/to/vault DAYS_BACK=14 EXPORT_BASE=/tmp ruby export.rb
```

**Note**: The export script automatically creates an `export.xml` file with all exported markdown files.

## Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/obsidian_daily_exporter_spec.rb

# Run with documentation format
bundle exec rspec --format documentation

# Run specific test by line number
bundle exec rspec spec/obsidian_daily_exporter_spec.rb:42
```

## Using as a Library

### Obsidian Daily Exporter
```ruby
require_relative 'lib/obsidian_daily_exporter'

# Basic usage
exporter = ObsidianDailyExporter.new(vault_path: '/path/to/vault')
result = exporter.run
# => { export_dir: "/tmp/export-...", total_files: 45, daily_notes_count: 7 }

# Custom configuration
exporter = ObsidianDailyExporter.new(
  vault_path: '/path/to/vault',
  days_back: 14,              # Export last 14 days
  export_base: '/custom/path', # Custom export location
  timestamp: '20260121_120000' # Fixed timestamp for testing
)

result = exporter.run(verbose: false)  # Suppress output
puts "Exported #{result[:total_files]} files"
```

### Markdown Concatenator
```ruby
require_relative 'lib/markdown_concatenator'

# Basic usage (current directory)
concatenator = MarkdownConcatenator.new
output = concatenator.run
# => "/current/path/export.xml"

# Custom configuration
concatenator = MarkdownConcatenator.new(
  export_dir: '/path/to/markdown/files',
  output_file: '/path/to/output.xml'
)
output = concatenator.run
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `OBSIDIAN_VAULT` | (required) | Path to your Obsidian vault |
| `DAYS_BACK` | `7` | Number of days to export |
| `EXPORT_BASE` | `/tmp` | Base directory for exports |

## Common Patterns

### Export with Custom Date Range
```ruby
exporter = ObsidianDailyExporter.new(
  vault_path: ENV['OBSIDIAN_VAULT'],
  days_back: 30  # Last month
)
exporter.run
```

### Silent Export (No Console Output)
```ruby
exporter = ObsidianDailyExporter.new(vault_path: vault_path)
result = exporter.run(verbose: false)
```

### Check What Would Be Exported
```ruby
exporter = ObsidianDailyExporter.new(vault_path: vault_path)
exporter.build_file_index(false)  # Silent
notes = exporter.get_daily_notes_for_last_n_days(7)
puts "Would export #{notes.length} daily notes"
notes.each { |n| puts "  - #{File.basename(n)}" }
```

### Extract Links from a Note
```ruby
require_relative 'lib/obsidian_daily_exporter'

content = File.read('my_note.md')
exporter = ObsidianDailyExporter.new(vault_path: '/dummy')
links = exporter.extract_wiki_links(content)
puts "Found links: #{links.join(', ')}"
```

## File Locations

### After Export
```
/tmp/export-20260121_143022/
├── 2026-01-21.md
├── 2026-01-20.md
├── linked-page.md
├── Projects/
│   └── Project Alpha.md
├── MANIFEST.md
└── export.xml          # Automatically generated!
```

### After Concatenation
```
export.xml (contains all markdown files in XML format)
```

**Note**: The `export.xml` file is automatically created in the export directory by `export.rb`.

## Troubleshooting

### "Vault path cannot be nil"
Set the `OBSIDIAN_VAULT` environment variable:
```bash
export OBSIDIAN_VAULT="/path/to/vault"
```

### No daily notes found
Check that your daily notes use one of these formats:
- `2026-01-21.md`
- `January 21, 2026.md`
- `21-01-2026.md`

### Tests failing
Make sure you've installed all dependencies:
```bash
bundle install
```

## Tips

1. **Use tree CLI for faster indexing**: `brew install tree` (macOS)
2. **Test before exporting**: Use a small `days_back` value first
3. **Check the manifest**: Always review `MANIFEST.md` in the export directory
4. **Backup your vault**: Before running any export scripts
5. **Use absolute paths**: Avoid confusion with relative paths

## Resources

- [README.md](README.md) - Full documentation
- [DEVELOPMENT.md](DEVELOPMENT.md) - Development guide
- [REFACTORING_SUMMARY.md](REFACTORING_SUMMARY.md) - What changed
