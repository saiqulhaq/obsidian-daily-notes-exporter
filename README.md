# Obsidian Daily Notes Exporter

A collection of Ruby scripts to export and process Obsidian vault notes.

## Project Status

✅ **47 passing tests** | 📦 Refactored for testability | 🔧 Actively maintained

## Overview

This project provides utilities for exporting and processing Obsidian vault notes:

**Daily Notes Exporter** - Exports daily notes and their linked pages from an Obsidian vault, automatically creating both markdown exports and an XML file for easy processing.

## Scripts

### export.rb

Exports daily notes from an Obsidian vault for the last N days, including all linked pages (wiki-style links), and automatically creates an XML file.

#### Features

- Exports daily notes for a configurable number of days (default: 7 days)
- Recursively follows wiki-style links `[[Page Name]]` up to 3 levels deep
- Handles multiple daily note naming conventions:
  - `YYYY-MM-DD` (e.g., `2026-01-21`)
  - `Month DD, YYYY` (e.g., `January 21, 2026`)
  - `DD-MM-YYYY` (e.g., `21-01-2026`)
  - And more...
- Preserves directory structure in the export
- Uses `tree` CLI for faster indexing if available, falls back to directory traversal
- Generates a detailed manifest of all exported files
- Unicode-aware link normalization
- **Automatically creates `export.xml` with all exported markdown files**

#### Configuration

Set the `OBSIDIAN_VAULT` environment variable to your vault path:

```bash
export OBSIDIAN_VAULT="/path/to/your/obsidian/vault"
```

Edit these constants in the script to customize:

```ruby
DAYS_BACK = 7              # Number of days to export
EXPORT_BASE = '/tmp'       # Export destination
```

#### Usage

```bash
ruby export.rb
```

The script will:
1. Index all markdown files in your vault
2. Find daily notes for the last N days
3. Export each note and recursively export linked pages
4. Create an export directory at `/tmp/export-YYYYMMDD_HHMMSS/`
5. Generate a `MANIFEST.md` file listing all exported files
6. **Automatically create `export.xml` with all exported markdown files**

#### Example Output

```
🚀 Starting Obsidian Daily Note Export
📁 Vault: /Users/yourname/Documents/Obsidian
📅 Exporting last 7 days
💾 Output: /tmp/export-20260121_143022
🌳 Tree CLI: ✅ Available

🔍 Building file index...
📑 Indexed 1234 files

📄 Found 7 daily notes

📋 Copied: 2026-01-21.md
🔗 2026-01-21.md found 3 links:
   - Project Alpha
   - Meeting Notes
   - Todo List
   ✓ Resolved to: /Users/yourname/Documents/Obsidian/Projects/Project Alpha.md
...

✅ Export complete!
📦 Exported to: /tmp/export-20260121_143022
📊 Total files copied: 45

🔄 Creating XML export...
✅ Wrote XML to /tmp/export-20260121_143022/export.xml
📦 Complete! Export available at: /tmp/export-20260121_143022
📄 XML file: /tmp/export-20260121_143022/export.xml
```

#### XML Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<notes>
  <note>
    <filename>example.md</filename>
    <path>subfolder/example.md</path>
    <content><![CDATA[
    # Markdown content here
    ]]></content>
  </note>
  ...
</notes>
```

## Requirements

- Ruby 2.7 or higher (tested with recent versions)
- Bundler for dependency management
- For `export.rb`:
  - Optional: `tree` CLI tool for faster indexing (install via `brew install tree` on macOS)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/saiqulhaq/obsidian-daily-notes-exporter.git
   cd obsidian-daily-notes-exporter
   ```

2. Install dependencies:
   ```bash
   bundle install
   ```

3. Set up your environment variable for the Obsidian vault (for `export.rb`):
   ```bash
   export OBSIDIAN_VAULT="/path/to/your/obsidian/vault"
   ```

## Development

The codebase has been refactored for better testability and maintainability:

- **lib/obsidian_daily_exporter.rb** - Main exporter class with dependency injection
- **lib/markdown_concatenator.rb** - XML concatenation functionality
- **spec/** - Comprehensive RSpec test suite

### Running Tests

Run all tests:
```bash
bundle exec rspec
```

Run specific test file:
```bash
bundle exec rspec spec/obsidian_daily_exporter_spec.rb
```

Run with detailed output:
```bash
bundle exec rspec --format documentation
```

### Project Structure

```
.
├── lib/
│   ├── obsidian_daily_exporter.rb  # Exporter class
│   └── markdown_concatenator.rb     # Concatenator class
├── spec/
│   ├── spec_helper.rb               # RSpec configuration
│   ├── obsidian_daily_exporter_spec.rb
│   └── markdown_concatenator_spec.rb
├── export.rb                         # CLI script for exporting & XML generation
├── Gemfile                          # Dependencies
└── README.md
```

## Use Cases

- Create backups of your recent daily notes with linked content
- Share a subset of your vault with collaborators
- Archive notes for a specific time period
- Export notes for external processing or publishing
- **Get a ready-to-use XML export in one command**
- Import exported data into other systems using the XML format

## License

See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

See [DEVELOPMENT.md](DEVELOPMENT.md) for development guidelines, testing instructions, and code structure information.

## Development Quick Start

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec

# Run with verbose output
bundle exec rspec --format documentation
```
