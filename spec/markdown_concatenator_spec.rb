require 'spec_helper'
require_relative '../lib/markdown_concatenator'
require 'tempfile'

RSpec.describe MarkdownConcatenator do
  let(:export_dir) { Dir.mktmpdir }
  let(:output_file) { File.join(export_dir, 'test_output.xml') }
  
  after do
    FileUtils.rm_rf(export_dir)
  end

  describe '#initialize' do
    it 'uses current directory by default' do
      concatenator = described_class.new
      expect(concatenator.export_dir).to eq(Dir.pwd)
    end

    it 'uses provided export directory' do
      concatenator = described_class.new(export_dir: export_dir)
      expect(concatenator.export_dir).to eq(export_dir)
    end

    it 'generates default output filename' do
      concatenator = described_class.new(export_dir: export_dir)
      expect(concatenator.output_file).to eq(File.join(export_dir, 'export.xml'))
    end

    it 'uses provided output filename' do
      concatenator = described_class.new(
        export_dir: export_dir,
        output_file: output_file
      )
      expect(concatenator.output_file).to eq(output_file)
    end
  end

  describe '#run' do
    let(:concatenator) do
      described_class.new(
        export_dir: export_dir,
        output_file: output_file
      )
    end

    context 'with markdown files' do
      before do
        # Create test markdown files
        File.write(File.join(export_dir, 'note1.md'), "# Note 1\n\nContent here")
        File.write(File.join(export_dir, 'note2.md'), "# Note 2\n\nMore content")
        
        # Create subdirectory with a file
        FileUtils.mkdir_p(File.join(export_dir, 'subdir'))
        File.write(File.join(export_dir, 'subdir', 'note3.md'), "# Note 3")
      end

      it 'creates an XML file' do
        concatenator.run
        expect(File.exist?(output_file)).to be true
      end

      it 'includes all markdown files' do
        concatenator.run
        content = File.read(output_file)
        
        expect(content).to include('<filename>note1.md</filename>')
        expect(content).to include('<filename>note2.md</filename>')
        expect(content).to include('<filename>note3.md</filename>')
      end

      it 'preserves file paths' do
        concatenator.run
        content = File.read(output_file)
        
        expect(content).to include('<path>note1.md</path>')
        expect(content).to include('<path>subdir/note3.md</path>')
      end

      it 'includes file content in CDATA sections' do
        concatenator.run
        content = File.read(output_file)
        
        expect(content).to include('<![CDATA[')
        expect(content).to include('# Note 1')
        expect(content).to include('Content here')
      end

      it 'has proper XML structure' do
        concatenator.run
        content = File.read(output_file)
        
        expect(content).to start_with('<?xml version="1.0" encoding="UTF-8"?>')
        expect(content).to include('<notes>')
        expect(content).to include('</notes>')
        expect(content).to include('<note>')
        expect(content).to include('</note>')
      end

      it 'escapes HTML in filenames and paths' do
        File.write(File.join(export_dir, 'note<test>.md'), "Content")
        concatenator.run
        content = File.read(output_file)
        
        expect(content).to include('note&lt;test&gt;.md')
      end

      it 'returns the output file path' do
        result = concatenator.run
        expect(result).to eq(output_file)
      end
    end

    context 'with skipped files' do
      before do
        File.write(File.join(export_dir, 'note.md'), "Content")
        File.write(File.join(export_dir, 'MANIFEST.md'), "Manifest")
        File.write(File.join(export_dir, 'export.xml'), "Old export")
      end

      it 'skips MANIFEST.md' do
        concatenator.run
        content = File.read(output_file)
        
        expect(content).not_to include('MANIFEST.md')
      end

      it 'skips export.xml' do
        concatenator.run
        content = File.read(output_file)
        
        # Count occurrences - should only appear in our structure, not as a note
        expect(content.scan(/<filename>export\.xml<\/filename>/).count).to eq(0)
      end

      it 'includes other markdown files' do
        concatenator.run
        content = File.read(output_file)
        
        expect(content).to include('<filename>note.md</filename>')
      end
    end

    context 'with no markdown files' do
      it 'creates empty XML structure' do
        concatenator.run
        content = File.read(output_file)
        
        expect(content).to include('<notes>')
        expect(content).to include('</notes>')
        expect(content).not_to include('<note>')
      end
    end

    context 'with special characters in content' do
      before do
        File.write(
          File.join(export_dir, 'special.md'),
          "Content with <tags> & special chars"
        )
      end

      it 'preserves special characters in CDATA' do
        concatenator.run
        content = File.read(output_file)
        
        # Content should be in CDATA, so tags should be preserved
        expect(content).to include('Content with <tags> & special chars')
      end
    end
  end

  describe 'integration with mocked file system' do
    let(:mock_fs) { instance_double('ConcatFileSystemAdapter') }
    let(:concatenator) do
      described_class.new(
        export_dir: export_dir,
        output_file: output_file,
        file_system: mock_fs
      )
    end

    it 'uses the file system adapter to read files' do
      allow(Dir).to receive(:chdir).and_yield
      allow(Dir).to receive(:glob).and_return(['test.md'])
      allow(mock_fs).to receive(:read_file).with(File.join(export_dir, 'test.md'))
        .and_return('Test content')
      
      output = StringIO.new
      allow(mock_fs).to receive(:write_file).and_yield(output)

      concatenator.run

      expect(mock_fs).to have_received(:read_file)
      expect(mock_fs).to have_received(:write_file)
    end
  end
end
