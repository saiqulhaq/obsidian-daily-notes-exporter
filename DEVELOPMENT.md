# Development Guide

## Overview

This project has been refactored to follow best practices for Ruby development, including:

- Separation of concerns (library code in `lib/`, CLI scripts separate)
- Dependency injection for testability
- Comprehensive test coverage with RSpec
- Clear project structure

## Key Refactorings

### 1. Dependency Injection

Both main classes now accept a `file_system` parameter for testing:

```ruby
# Production use
exporter = ObsidianDailyExporter.new(vault_path: '/path/to/vault')

# Testing with mock
mock_fs = instance_double('FileSystemAdapter')
exporter = ObsidianDailyExporter.new(
  vault_path: '/path/to/vault',
  file_system: mock_fs
)
```

### 2. Fixed Issues

- **Removed duplicate method**: The original `export.rb` had `export_note_with_links` defined twice
- **Better error handling**: Now validates vault_path on initialization
- **Cleaner API**: Public methods are clearly separated from private helpers

### 3. File Structure

```
lib/
├── obsidian_daily_exporter.rb    # Main exporter logic
│   ├── ObsidianDailyExporter      # Main class
│   └── FileSystemAdapter          # Adapter for file operations
└── markdown_concatenator.rb       # XML concatenation logic
    ├── MarkdownConcatenator       # Main class
    └── ConcatFileSystemAdapter    # Adapter for file operations

spec/
├── spec_helper.rb                 # RSpec configuration
├── obsidian_daily_exporter_spec.rb
└── markdown_concatenator_spec.rb

export.rb                          # CLI wrapper for exporter + XML generation
```

## Running Tests

### Run all tests
```bash
bundle exec rspec
```

### Run specific test file
```bash
bundle exec rspec spec/obsidian_daily_exporter_spec.rb
```

### Run with detailed output
```bash
bundle exec rspec --format documentation
```

### Run specific test
```bash
bundle exec rspec spec/obsidian_daily_exporter_spec.rb:42
```

### Generate coverage report
The test suite includes 47 test cases covering:
- Input validation
- Wiki link extraction
- File indexing
- Daily note discovery
- Recursive link following
- XML generation
- File system operations

## Test Coverage

### ObsidianDailyExporter (30 specs)
- Initialization and configuration
- Name normalization
- Wiki link extraction patterns
- File finding and indexing
- Date-based note discovery
- Recursive export with depth limits
- Manifest generation
- File size formatting

### MarkdownConcatenator (17 specs)
- Configuration and setup
- XML structure generation
- File filtering (skipping MANIFEST.md, export.xml)
- HTML escaping
- CDATA content preservation
- Integration with file system

## Adding New Tests

When adding new functionality:

1. Write the test first (TDD):
```ruby
describe '#new_method' do
  it 'does something specific' do
    result = subject.new_method(input)
    expect(result).to eq(expected)
  end
end
```

2. Run the test and watch it fail:
```bash
bundle exec rspec spec/your_spec.rb
```

3. Implement the feature

4. Run the test again and ensure it passes

## Continuous Integration

Consider adding a `.github/workflows/test.yml` for CI:

```yaml
name: Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true
      - run: bundle exec rspec
```

## Code Style

- Use 2 spaces for indentation
- Keep methods small and focused
- Add comments for complex logic
- Use descriptive variable names
- Follow Ruby naming conventions (snake_case for methods, PascalCase for classes)

## Debugging

Use `pry` for debugging:

```ruby
require 'pry'

def some_method
  # ... code ...
  binding.pry  # Debugger will stop here
  # ... more code ...
end
```

Then run your script or tests, and you'll get an interactive REPL at the breakpoint.
