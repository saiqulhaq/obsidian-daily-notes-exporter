require 'fileutils'
require 'cgi'

class MarkdownConcatenator
  SKIP_FILES = ['MANIFEST.md', 'export.xml'].freeze

  attr_reader :export_dir, :output_file

  def initialize(export_dir: Dir.pwd, output_file: nil, file_system: nil)
    @export_dir = export_dir
    @output_file = output_file || File.join(@export_dir, 'export.xml')
    @file_system = file_system || ConcatFileSystemAdapter.new
  end

  def run
    markdown_files = find_markdown_files

    @file_system.write_file(@output_file) do |out|
      out.puts %(<?xml version="1.0" encoding="UTF-8"?>)
      out.puts %(<notes>)

      markdown_files.each do |rel_path|
        abs_path = File.join(@export_dir, rel_path)
        filename = File.basename(rel_path)
        content = @file_system.read_file(abs_path)

        out.puts "  <note>"
        out.puts "    <filename>#{CGI.escapeHTML(filename)}</filename>"
        out.puts "    <path>#{CGI.escapeHTML(rel_path)}</path>"
        out.puts "    <content><![CDATA["
        out.puts content
        out.puts "    ]]></content>"
        out.puts "  </note>"
      end

      out.puts %(</notes>)
    end

    puts "✅ Wrote XML to #{@output_file}"
    @output_file
  end

  private

  def find_markdown_files
    Dir.chdir(@export_dir) do
      Dir.glob('**/*.md')
        .reject { |f| SKIP_FILES.include?(File.basename(f)) }
        .sort
    end
  end
end

# File system adapter for concatenator
class ConcatFileSystemAdapter
  def read_file(path)
    File.read(path)
  end

  def write_file(path, &block)
    File.open(path, 'w', &block)
  end
end
