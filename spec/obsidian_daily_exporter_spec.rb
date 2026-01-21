require 'spec_helper'
require_relative '../lib/obsidian_daily_exporter'

RSpec.describe ObsidianDailyExporter do
  let(:vault_path) { '/tmp/test_vault' }
  let(:export_base) { '/tmp/test_exports' }
  let(:timestamp) { '20260121_120000' }
  let(:mock_fs) { instance_double('FileSystemAdapter') }

  let(:exporter) do
    described_class.new(
      vault_path: vault_path,
      days_back: 3,
      export_base: export_base,
      timestamp: timestamp,
      file_system: mock_fs
    )
  end

  before do
    allow(mock_fs).to receive(:mkdir_p)
    allow(mock_fs).to receive(:file_exist?).and_return(false)
  end

  describe '#initialize' do
    it 'raises an error when vault_path is nil' do
      expect {
        described_class.new(vault_path: nil)
      }.to raise_error(ArgumentError, "Vault path cannot be nil")
    end

    it 'raises an error when vault_path is empty' do
      expect {
        described_class.new(vault_path: '')
      }.to raise_error(ArgumentError, "Vault path cannot be nil")
    end

    it 'sets default values correctly' do
      exporter = described_class.new(vault_path: vault_path)
      expect(exporter.export_dir).to match(%r{/tmp/export-\d+_\d+})
    end

    it 'uses provided timestamp' do
      expect(exporter.export_dir).to eq("#{export_base}/export-#{timestamp}")
    end
  end

  describe '#normalize_name' do
    it 'returns empty string for nil' do
      expect(exporter.normalize_name(nil)).to eq('')
    end

    it 'converts to lowercase' do
      expect(exporter.normalize_name('MyFile')).to eq('myfile')
    end

    it 'normalizes unicode dashes to ASCII hyphen' do
      expect(exporter.normalize_name("My\u2013File")).to eq('my-file')
    end

    it 'collapses whitespace' do
      expect(exporter.normalize_name('My   File')).to eq('my file')
    end

    it 'strips leading and trailing whitespace' do
      expect(exporter.normalize_name('  MyFile  ')).to eq('myfile')
    end
  end

  describe '#extract_wiki_links' do
    it 'extracts simple wiki links' do
      content = "Some text [[Page Name]] more text"
      expect(exporter.extract_wiki_links(content)).to eq(['Page Name'])
    end

    it 'extracts links with display text' do
      content = "Text [[Page Name|Display Text]] more"
      expect(exporter.extract_wiki_links(content)).to eq(['Page Name'])
    end

    it 'extracts links with anchors' do
      content = "Text [[Page Name#Section]] more"
      expect(exporter.extract_wiki_links(content)).to eq(['Page Name'])
    end

    it 'extracts multiple links' do
      content = "[[First]] and [[Second]] and [[Third]]"
      expect(exporter.extract_wiki_links(content)).to eq(['First', 'Second', 'Third'])
    end

    it 'handles folder paths' do
      content = "[[Folder/Page Name]]"
      expect(exporter.extract_wiki_links(content)).to eq(['Folder/Page Name'])
    end

    it 'returns unique links' do
      content = "[[Page]] and [[Page]] again"
      expect(exporter.extract_wiki_links(content)).to eq(['Page'])
    end

    it 'returns empty array for no links' do
      content = "Just plain text"
      expect(exporter.extract_wiki_links(content)).to eq([])
    end
  end

  describe '#get_daily_notes_for_last_n_days' do
    before do
      Timecop.freeze(Time.local(2026, 1, 21, 12, 0, 0))
    end

    after do
      Timecop.return
    end

    it 'finds daily notes in YYYY-MM-DD format' do
      allow(mock_fs).to receive(:file_exist?)
        .with("#{vault_path}/2026-01-21.md").and_return(true)
      allow(mock_fs).to receive(:file_exist?)
        .with("#{vault_path}/2026-01-20.md").and_return(true)

      notes = exporter.get_daily_notes_for_last_n_days(2)
      expect(notes).to include("#{vault_path}/2026-01-21.md")
      expect(notes).to include("#{vault_path}/2026-01-20.md")
    end

    it 'finds daily notes with different naming conventions' do
      allow(mock_fs).to receive(:file_exist?).and_return(false)
      allow(mock_fs).to receive(:file_exist?)
        .with("#{vault_path}/January 21, 2026.md").and_return(true)

      notes = exporter.get_daily_notes_for_last_n_days(1)
      expect(notes).to include("#{vault_path}/January 21, 2026.md")
    end

    it 'returns unique notes only' do
      allow(mock_fs).to receive(:file_exist?)
        .with("#{vault_path}/2026-01-21.md").and_return(true)

      notes = exporter.get_daily_notes_for_last_n_days(1)
      expect(notes.length).to eq(1)
    end
  end

  describe '#find_file_for_link' do
    before do
      exporter.instance_variable_set(:@file_index, {
        'mypage' => "#{vault_path}/MyPage.md",
        'another page' => "#{vault_path}/Another Page.md"
      })
    end

    it 'finds file by normalized name' do
      result = exporter.find_file_for_link('MyPage')
      expect(result).to eq("#{vault_path}/MyPage.md")
    end

    it 'handles folder paths by using last component' do
      result = exporter.find_file_for_link('Folder/MyPage')
      expect(result).to eq("#{vault_path}/MyPage.md")
    end

    it 'returns nil for non-existent links' do
      result = exporter.find_file_for_link('NonExistent')
      expect(result).to be_nil
    end
  end

  describe '#format_size' do
    it 'formats bytes' do
      expect(exporter.send(:format_size, 512)).to eq('512B')
    end

    it 'formats kilobytes' do
      expect(exporter.send(:format_size, 2048)).to eq('2.0KB')
    end

    it 'formats megabytes' do
      expect(exporter.send(:format_size, 2_097_152)).to eq('2.0MB')
    end
  end

  describe '#run' do
    let(:daily_note_path) { "#{vault_path}/2026-01-21.md" }
    let(:linked_note_path) { "#{vault_path}/LinkedPage.md" }

    before do
      Timecop.freeze(Time.local(2026, 1, 21, 12, 0, 0))
      
      allow(exporter).to receive(:build_file_index)
      allow(mock_fs).to receive(:file_exist?).and_return(false)
      allow(mock_fs).to receive(:file_exist?)
        .with(daily_note_path).and_return(true)
      allow(mock_fs).to receive(:file_exist?)
        .with(linked_note_path).and_return(true)
      allow(mock_fs).to receive(:read_file)
        .with(daily_note_path).and_return("# Daily Note\n\n[[LinkedPage]]")
      allow(mock_fs).to receive(:read_file)
        .with(linked_note_path).and_return("# Linked Page")
      allow(mock_fs).to receive(:copy_file)
      allow(mock_fs).to receive(:file_size).and_return(1024)
      allow(mock_fs).to receive(:write_file)

      exporter.instance_variable_set(:@file_index, {
        '2026-01-21' => daily_note_path,
        'linkedpage' => linked_note_path
      })
    end

    after do
      Timecop.return
    end

    it 'exports daily notes and their links' do
      result = exporter.run(verbose: false)
      
      expect(result[:total_files]).to eq(2)
      expect(result[:daily_notes_count]).to eq(1)
      expect(exporter.copied_files).to include(daily_note_path)
      expect(exporter.copied_files).to include(linked_note_path)
    end

    it 'creates manifest file' do
      expect(mock_fs).to receive(:write_file)
        .with("#{export_base}/export-#{timestamp}/MANIFEST.md", anything)
      
      exporter.run(verbose: false)
    end
  end

  describe '#export_note_with_links' do
    let(:note_path) { "#{vault_path}/note.md" }
    let(:linked_path) { "#{vault_path}/linked.md" }

    before do
      allow(mock_fs).to receive(:file_exist?).with(note_path).and_return(true)
      allow(mock_fs).to receive(:file_exist?).with(linked_path).and_return(true)
      allow(mock_fs).to receive(:read_file).with(note_path).and_return("[[Linked]]")
      allow(mock_fs).to receive(:read_file).with(linked_path).and_return("Content")
      allow(mock_fs).to receive(:copy_file)

      exporter.instance_variable_set(:@file_index, {
        'linked' => linked_path
      })
    end

    it 'does not export beyond max depth' do
      exporter.export_note_with_links(note_path, 4, 3, verbose: false)
      expect(exporter.copied_files).to be_empty
    end

    it 'does not export same file twice' do
      exporter.export_note_with_links(note_path, 0, 3, verbose: false)
      exporter.export_note_with_links(note_path, 0, 3, verbose: false)
      # The file should be copied only once since it's tracked in @copied_files
      expect(exporter.copied_files.size).to eq(2)  # note_path and linked_path
      expect(exporter.processed_links.size).to eq(2)
    end

    it 'recursively exports linked notes' do
      exporter.export_note_with_links(note_path, 0, 3, verbose: false)
      expect(exporter.copied_files).to include(note_path)
      expect(exporter.copied_files).to include(linked_path)
    end
  end
end
