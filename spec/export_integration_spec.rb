require 'spec_helper'
require 'open3'
require 'tmpdir'

RSpec.describe 'export.rb integration' do
  let(:test_vault) { Dir.mktmpdir('test_vault') }
  let(:export_base) { Dir.mktmpdir('test_exports') }

  before do
    # Create a simple daily note
    File.write(File.join(test_vault, '2026-01-21.md'), <<~MD)
      # Daily Note Jan 21

      Some content here.
      
      [[Linked Page]]
    MD

    # Create a linked page
    File.write(File.join(test_vault, 'Linked Page.md'), <<~MD)
      # Linked Page

      This is a linked page.
    MD
  end

  after do
    FileUtils.rm_rf(test_vault)
    FileUtils.rm_rf(export_base)
  end

  it 'exports daily notes and creates XML file' do
    env = {
      'OBSIDIAN_VAULT' => test_vault,
      'DAYS_BACK' => '1',
      'EXPORT_BASE' => export_base
    }

    stdout, stderr, status = Open3.capture3(
      env,
      'ruby',
      File.expand_path('../export.rb', __dir__)
    )

    expect(status.success?).to be true
    expect(stdout).to include('Export complete!')
    expect(stdout).to include('Creating XML export')
    expect(stdout).to include('Wrote XML to')

    # Find the export directory
    export_dirs = Dir.glob(File.join(export_base, 'export-*'))
    expect(export_dirs).not_to be_empty

    export_dir = export_dirs.first

    # Check that markdown files were exported
    expect(File.exist?(File.join(export_dir, '2026-01-21.md'))).to be true
    expect(File.exist?(File.join(export_dir, 'Linked Page.md'))).to be true

    # Check that XML file was created
    xml_file = File.join(export_dir, 'export.xml')
    expect(File.exist?(xml_file)).to be true

    # Verify XML content
    xml_content = File.read(xml_file)
    expect(xml_content).to include('<?xml version="1.0" encoding="UTF-8"?>')
    expect(xml_content).to include('<notes>')
    expect(xml_content).to include('<filename>2026-01-21.md</filename>')
    expect(xml_content).to include('<filename>Linked Page.md</filename>')
    expect(xml_content).to include('Daily Note Jan 21')
    expect(xml_content).to include('This is a linked page')
  end
end
