# Obsidian Daily Notes Exporter

A collection of Ruby scripts to export and process Obsidian vault notes.

## Overview

This project provides two main utilities for working with Obsidian markdown files:

1. **Daily Notes Exporter** - Exports daily notes and their linked pages from an Obsidian vault
2. **XML Concatenator** - Converts markdown files into a single XML document

## Scripts

### export.rb

Exports daily notes from an Obsidian vault for the last N days, including all linked pages (wiki-style links).

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
```

### concat.rb

Converts all markdown files in the current directory into a single XML file.

#### Features

- Recursively finds all `.md` files in the current directory
- Outputs a structured XML file with proper encoding
- Escapes HTML/XML special characters
- Uses CDATA sections for content to preserve formatting
- Skips specific files (`MANIFEST.md`, `export.xml`)

#### Usage

```bash
cd /path/to/markdown/files
ruby concat.rb
```

This will create `export.xml` in the current directory.

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

- Ruby (tested with recent versions)
- For `export.rb`:
  - `pry` gem (for debugging): `gem install pry`
  - Optional: `tree` CLI tool for faster indexing (install via `brew install tree` on macOS)

## Installation

1. Clone this repository
2. Install required gems:
   ```bash
   gem install pry
   ```
3. Set up your environment variable for the Obsidian vault (for `export.rb`)

## Use Cases

### export.rb
- Create backups of your recent daily notes
- Share a subset of your vault with collaborators
- Archive notes for a specific time period
- Export notes for external processing or publishing

### concat.rb
- Combine exported notes into a single XML file
- Prepare notes for import into other systems
- Create a searchable archive format
- Generate data for analysis or processing

## License

See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.
