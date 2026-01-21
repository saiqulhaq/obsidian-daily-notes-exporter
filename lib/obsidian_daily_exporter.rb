require 'fileutils'
require 'time'
require 'json'
require 'set'
require 'date'

class ObsidianDailyExporter
  attr_reader :export_dir, :copied_files, :processed_links

  # Configuration
  DEFAULT_DAYS_BACK = 7
  DEFAULT_EXPORT_BASE = '/tmp'
  DEFAULT_MAX_DEPTH = 3

  def initialize(vault_path:, days_back: DEFAULT_DAYS_BACK, export_base: DEFAULT_EXPORT_BASE, 
                 timestamp: nil, file_system: nil)
    raise ArgumentError, "Vault path cannot be nil" if vault_path.nil? || vault_path.empty?
    
    @vault_path = vault_path
    @daily_notes_dir = vault_path
    @days_back = days_back
    @export_base = export_base
    @timestamp = timestamp || Time.now.strftime('%Y%m%d_%H%M%S')
    @export_dir = File.join(@export_base, "export-#{@timestamp}")
    @copied_files = Set.new
    @processed_links = Set.new
    @file_index = {} # Maps lowercase filenames to full paths
    @tree_available = check_tree_available
    @file_system = file_system || FileSystemAdapter.new
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

  def run(verbose: true)
    log "🚀 Starting Obsidian Daily Note Export", verbose
    log "📁 Vault: #{@vault_path}", verbose
    log "📅 Exporting last #{@days_back} days", verbose
    log "💾 Output: #{@export_dir}", verbose
    log "🌳 Tree CLI: #{@tree_available ? '✅ Available' : '❌ Not available, falling back to file traversal'}\n", verbose

    # Create export directory
    @file_system.mkdir_p(@export_dir)

    # Build file index using tree or fallback
    build_file_index(verbose)

    # Get daily notes for last N days
    daily_notes = get_daily_notes_for_last_n_days(@days_back)
    log "📄 Found #{daily_notes.length} daily notes\n", verbose

    # Export each daily note and its linked pages
    daily_notes.each do |note_path|
      export_note_with_links(note_path, verbose: verbose)
    end

    # Create manifest
    create_manifest(daily_notes)

    log "\n✅ Export complete!", verbose
    log "📦 Exported to: #{@export_dir}", verbose
    log "📊 Total files copied: #{@copied_files.length}", verbose

    {
      export_dir: @export_dir,
      total_files: @copied_files.length,
      daily_notes_count: daily_notes.length
    }
  end

  def build_file_index(verbose = true)
    log "🔍 Building file index...", verbose

    if @tree_available
      build_index_with_tree
    else
      build_index_with_traversal
    end

    log "📑 Indexed #{@file_index.length} files\n", verbose
  end

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
        full_path = File.join(@daily_notes_dir, "#{name}.md")
        if @file_system.file_exist?(full_path)
          daily_notes << full_path
          break
        end

        # Nested path (e.g., Daily Notes/2026-01-21/2026-01-21.md)
        full_path_nested = File.join(@daily_notes_dir, name, "#{name}.md")
        if @file_system.file_exist?(full_path_nested)
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

  def extract_wiki_links(content)
    links = []
    # Regex to match [[Page Name]] or [[Page Name|Display Text]]
    # Also handles subpage links like [[Page/Subpage]]
    content.scan(/\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]+)?\]\]/) do |match|
      links << match[0].strip
    end
    links.uniq
  end

  def find_file_for_link(link)
    # Obsidian link may be "Folder/Page", use last component
    search_name = link.split('/').last
    key = normalize_name(search_name)

    return @file_index[key] if @file_index[key]

    nil
  end

  # Export a note and all its linked pages recursively
  def export_note_with_links(note_path, depth = 0, max_depth = DEFAULT_MAX_DEPTH, verbose: true)
    return if depth > max_depth
    return unless @file_system.file_exist?(note_path)
    return if @processed_links.include?(note_path)

    @processed_links.add(note_path)
    copy_file(note_path, verbose)

    content = @file_system.read_file(note_path)
    wiki_links = extract_wiki_links(content)

    # DEBUG: Print what we found
    if wiki_links.any? && verbose
      puts "🔗 #{File.basename(note_path)} found #{wiki_links.length} links:"
      wiki_links.each { |l| puts "   - #{l}" }
    end

    wiki_links.each do |link|
      linked_file = find_file_for_link(link)
      if verbose
        if linked_file
          puts "   ✓ Resolved to: #{linked_file}"
        else
          puts "   ✗ NOT FOUND: #{link}"
        end
      end

      if linked_file && @file_system.file_exist?(linked_file)
        export_note_with_links(linked_file, depth + 1, max_depth, verbose: verbose)
      end
    end
  end

  private

  def log(message, verbose = true)
    puts message if verbose
  end

  # Check if tree CLI is available
  def check_tree_available
    system('which tree > /dev/null 2>&1')
  end

  def index_tree_json(nodes, base_path = '')
    return unless nodes.is_a?(Array)

    nodes.each do |node|
      next if node['type'] == 'report'
      next unless node['name'].is_a?(String) && !node['name'].empty?

      current_path = base_path.empty? ? node['name'] : File.join(base_path, node['name'])

      # Don't re-prepend VAULT_PATH if current_path is already absolute
      full_path = if current_path.start_with?('/')
                    current_path
                  else
                    File.join(@vault_path, current_path)
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
      output = `tree -J -a "#{@vault_path}" 2>/dev/null`

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
    Dir.glob("#{@vault_path}/**/*.md").each do |file|
      raw = File.basename(file, '.md')
      key = normalize_name(raw)
      @file_index[key] ||= file
    end
  end

  # Copy file to export directory, preserving relative structure
  def copy_file(source, verbose = true)
    return if @copied_files.include?(source)

    # Calculate relative path from vault
    relative_path = source.sub(@vault_path, '').sub(/^\//, '')
    dest = File.join(@export_dir, relative_path)

    # Create destination directory if needed
    @file_system.mkdir_p(File.dirname(dest))

    # Copy file
    @file_system.copy_file(source, dest)
    @copied_files.add(source)

    log "📋 Copied: #{relative_path}", verbose
  end

  # Create a manifest file listing all exported items
  def create_manifest(daily_notes)
    manifest_path = File.join(@export_dir, 'MANIFEST.md')

    content = "# Export Manifest\n\n"
    content += "**Exported**: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}\n"
    content += "**Days**: Last #{@days_back} days\n"
    content += "**Total Files**: #{@copied_files.length}\n"
    content += "**Tree CLI Used**: #{@tree_available ? 'Yes' : 'No (fallback to traversal)'}\n\n"

    content += "## Daily Notes\n"
    daily_notes.each do |note|
      relative = note.sub(@vault_path, '').sub(/^\//, '')
      content += "- #{relative}\n"
    end

    content += "\n## All Exported Files\n"
    @copied_files.sort.each do |file|
      relative = file.sub(@vault_path, '').sub(/^\//, '')
      size = @file_system.file_size(file)
      content += "- #{relative} (#{format_size(size)})\n"
    end

    @file_system.write_file(manifest_path, content)
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

# File system adapter for dependency injection and testing
class FileSystemAdapter
  def file_exist?(path)
    File.exist?(path)
  end

  def read_file(path)
    File.read(path)
  end

  def write_file(path, content)
    File.write(path, content)
  end

  def copy_file(source, dest)
    FileUtils.copy_file(source, dest)
  end

  def mkdir_p(path)
    FileUtils.mkdir_p(path)
  end

  def file_size(path)
    File.size(path)
  end
end
