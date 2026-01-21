#!/usr/bin/env ruby
require 'fileutils'
require 'cgi'

EXPORT_DIR  = Dir.pwd
OUTPUT_FILE = File.join(EXPORT_DIR, 'export.xml')
SKIP_FILES  = ['MANIFEST.md', 'export.xml']

def markdown_files(root)
  Dir.chdir(root) do
    Dir.glob('**/*.md')
      .reject { |f| SKIP_FILES.include?(File.basename(f)) }
      .sort
  end
end

File.open(OUTPUT_FILE, 'w') do |out|
  out.puts %(<?xml version="1.0" encoding="UTF-8"?>)
  out.puts %(<notes>)

  markdown_files(EXPORT_DIR).each do |rel_path|
    abs_path = File.join(EXPORT_DIR, rel_path)
    filename = File.basename(rel_path)
    content  = File.read(abs_path)

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

puts "✅ Wrote XML to #{OUTPUT_FILE}"
