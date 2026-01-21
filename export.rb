require 'fileutils'
require 'time'
require 'json'
require 'set'
require 'pry'

class ObsidianDailyExporter
  # Configuration
  VAULT_PATH = ENV['OBSIDIAN_VAULT']
  # DAILY_NOTES_DIR = File.join(VAULT_PATH, 'Daily Notes') # Adjust to your daily notes folder
  DAILY_NOTES_DIR = File.join(VAULT_PATH, '') # Adjust to your daily notes folder
  DAYS_BACK = 7
  EXPORT_BASE = '/tmp'

  def initialize
    @timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
    @export_dir = File.join(EXPORT_BASE, "export-#{@timestamp}")
    @copied_files = Set.new
    @processed_links = Set.new
    @file_index = {} # Maps lowercase filenames to full paths
    @tree_available = check_tree_available
  end

  def normalize_name(name)
    return '' unless name
    n = name.dup

    # Normalize Unicode dashes to ASCII hyphen
    n.tr!("\u2010\u2011\u2012\u2013\u2014\u2015", '-')  # various dash types -> "-"

    # Collapse whitespace
    n.gsub!(/\s+/, ' ')

    n.strip.downcase
  end

  def run
    puts "🚀 Starting Obsidian Daily Note Export"
    puts "📁 Vault: #{VAULT_PATH}"
    puts "📅 Exporting last #{DAYS_BACK} days"
    puts "💾 Output: #{@export_dir}"
    puts "🌳 Tree CLI: #{@tree_available ? '✅ Available' : '❌ Not available, falling back to file traversal'}\n"

    # Create export directory
    FileUtils.mkdir_p(@export_dir)

    # Build file index using tree or fallback
    build_file_index

    # Get daily notes for last 14 days
    daily_notes = get_daily_notes_for_last_n_days(DAYS_BACK)
    puts "📄 Found #{daily_notes.length} daily notes\n"

    # Export each daily note and its linked pages
    daily_notes.each do |note_path|
      export_note_with_links(note_path)
    end

    # Create manifest
    create_manifest(daily_notes)

    puts "\n✅ Export complete!"
    puts "📦 Exported to: #{@export_dir}"
    puts "📊 Total files copied: #{@copied_files.length}"
  end

  private

  # Check if tree CLI is available
  def check_tree_available
    system('which tree > /dev/null 2>&1')
  end

  # Build file index using tree CLI or directory traversal
  def build_file_index
    puts "🔍 Building file index..."

    if @tree_available
      build_index_with_tree
    else
      build_index_with_traversal
    end

    puts "📑 Indexed #{@file_index.length} files\n"
  end

  def index_tree_json(nodes, base_path = '')
    return unless nodes.is_a?(Array)

    nodes.each do |node|
      next if node['type'] == 'report'
      next unless node['name'].is_a?(String) && !node['name'].empty?

      current_path = base_path.empty? ? node['name'] : File.join(base_path, node['name'])

      # FIX: Don't re-prepend VAULT_PATH if current_path is already absolute
      full_path = if current_path.start_with?('/')
                    current_path
                  else
                    File.join(VAULT_PATH, current_path)
                  end

      if node['type'] == 'file' && File.extname(full_path) == '.md'
        raw = File.basename(full_path, '.md')
        key = normalize_name(raw)
        @file_index[key] ||= full_path
      elsif node['type'] == 'directory' && node['contents']
        index_tree_json(node['contents'], current_path)
      end
    end
  end

  # Build index using `tree -J` (JSON output)
  def build_index_with_tree
    begin
      # tree -J outputs JSON representation of the tree
      output = `tree -J -a "#{VAULT_PATH}" 2>/dev/null`

      if $?.success? && !output.empty?
        tree_data = JSON.parse(output)
        index_tree_json(tree_data)
      else
        puts "⚠️  Tree command failed, falling back to directory traversal"
        build_index_with_traversal
      end
    rescue JSON::ParserError => e
      puts "⚠️  Failed to parse tree JSON: #{e.message}, falling back"
      build_index_with_traversal
    end
  end

  def build_index_with_traversal
    Dir.glob("#{VAULT_PATH}/**/*.md").each do |file|
      raw = File.basename(file, '.md')
      key = normalize_name(raw)
      @file_index[key] ||= file
    end
  end

  # Export a note and all its linked pages recursively
  def export_note_with_links(note_path, depth = 0, max_depth = 3)
    return if depth > max_depth
    return unless File.exist?(note_path)
    return if @processed_links.include?(note_path)

    @processed_links.add(note_path)

    # Copy the note itself
    copy_file(note_path)

    # Parse and find all wiki links [[Page Name]]
    content = File.read(note_path)
    wiki_links = extract_wiki_links(content)

    # Export each linked page
    wiki_links.each do |link|
      linked_file = find_file_for_link(link)
      if linked_file && File.exist?(linked_file)
        export_note_with_links(linked_file, depth + 1, max_depth)
      else
        puts "⚠️  Link not found: #{link}"
      end
    end
  end

  def export_note_with_links(note_path, depth = 0, max_depth = 3)
    return if depth > max_depth
    return unless File.exist?(note_path)
    return if @processed_links.include?(note_path)

    @processed_links.add(note_path)
    copy_file(note_path)

    content = File.read(note_path)
    wiki_links = extract_wiki_links(content)

    # DEBUG: Print what we found
    if wiki_links.any?
      puts "🔗 #{File.basename(note_path)} found #{wiki_links.length} links:"
      wiki_links.each { |l| puts "   - #{l}" }
    end

    wiki_links.each do |link|
      linked_file = find_file_for_link(link)
      puts "   ✓ Resolved to: #{linked_file}" if linked_file
      puts "   ✗ NOT FOUND: #{link}" unless linked_file

      if linked_file && File.exist?(linked_file)
        export_note_with_links(linked_file, depth + 1, max_depth)
      end
    end
  end

  # Extract wiki links [[...]] from markdown content
  def extract_wiki_links(content)
    links = []
    # Regex to match [[Page Name]] or [[Page Name|Display Text]]
    # Also handles subpage links like [[Page/Subpage]]
    content.scan(/\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]+)?\]\]/) do |match|
      links << match[0].strip
    end
    links.uniq
  end

  # Find a file in the vault for a given link (uses index for speed)
  def find_file_for_link(link)
    # Obsidian link may be "Folder/Page", use last component
    search_name = link.split('/').last
    key = normalize_name(search_name)

    return @file_index[key] if @file_index[key]

    nil
  end


  # Get all daily notes from the last N days
  def get_daily_notes_for_last_n_days(days)
    daily_notes = []
    days.times do |i|
      date = Date.today - i

      # Try multiple common naming conventions
      possible_names = [
        date.to_s,                           # YYYY-MM-DD
        date.strftime('%Y-%m-%d'),
        date.strftime('%B %d, %Y'),          # January 21, 2026
        date.strftime('%b %d, %Y'),          # Jan 21, 2026
        date.strftime('%d-%m-%Y'),           # 21-01-2026
      ]

      # Check each naming convention
      possible_names.each do |name|
        # Direct path
        full_path = File.join(DAILY_NOTES_DIR, "#{name}.md")
        if File.exist?(full_path)
          daily_notes << full_path
          break
        end

        # Nested path (e.g., Daily Notes/2026-01-21/2026-01-21.md)
        full_path_nested = File.join(DAILY_NOTES_DIR, name, "#{name}.md")
        if File.exist?(full_path_nested)
          daily_notes << full_path_nested
          break
        end

        # Try via file index lookup
        key = name.downcase
        if @file_index[key]
          daily_notes << @file_index[key]
          break
        end
      end
    end

    daily_notes.uniq
  end


  # Copy file to export directory, preserving relative structure
  def copy_file(source)
    return if @copied_files.include?(source)

    # Calculate relative path from vault
    relative_path = source.sub(VAULT_PATH, '').sub(/^\//, '')
    dest = File.join(@export_dir, relative_path)

    # Create destination directory if needed
    FileUtils.mkdir_p(File.dirname(dest))

    # Copy file
    FileUtils.copy_file(source, dest)
    @copied_files.add(source)

    puts "📋 Copied: #{relative_path}"
  end

  # Create a manifest file listing all exported items
  def create_manifest(daily_notes)
    manifest_path = File.join(@export_dir, 'MANIFEST.md')

    content = "# Export Manifest\n\n"
    content += "**Exported**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n"
    content += "**Days**: Last #{DAYS_BACK} days\n"
    content += "**Total Files**: #{@copied_files.length}\n"
    content += "**Tree CLI Used**: #{@tree_available ? 'Yes' : 'No (fallback to traversal)'}\n\n"

    content += "## Daily Notes\n"
    daily_notes.each do |note|
      relative = note.sub(VAULT_PATH, '').sub(/^\//, '')
      content += "- #{relative}\n"
    end

    content += "\n## All Exported Files\n"
    @copied_files.sort.each do |file|
      relative = file.sub(VAULT_PATH, '').sub(/^\//, '')
      size = File.size(file)
      content += "- #{relative} (#{format_size(size)})\n"
    end

    File.write(manifest_path, content)
    puts "\n📝 Manifest created: #{manifest_path}"
  end

  # Format file size for readability
  def format_size(bytes)
    case bytes
    when 0..1024
      "#{bytes}B"
    when 1024..1024**2
      "#{(bytes / 1024.0).round(1)}KB"
    else
      "#{(bytes / (1024**2).to_f).round(1)}MB"
    end
  end
end

# Run the exporter
ObsidianDailyExporter.new.run