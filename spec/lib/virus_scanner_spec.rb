require 'spec_helper'
require 'virus_scanner'

RSpec.describe VirusScanner do
  describe "scanning a file" do
    subject(:scanner) { described_class.new }

    let(:file_path) { '/path/to/file' }
    let(:output) { '' }
    let(:status) { instance_double('Process::Status', exitstatus: exitstatus) }
    let(:exitstatus) { 0 }

    before do
      allow(Open3).to receive(:capture2e).and_return([output, status])
    end

    it "calls out to clamdscan" do
      expect(Open3).to receive(:capture2e).with("govuk_clamscan", "--no-summary", file_path)

      scanner.scan(file_path)
    end

    context 'when clamdscan detects no virus' do
      let(:exitstatus) { 0 }

      it "returns true" do
        expect(scanner.scan(file_path)).to eq(true)
      end
    end

    context 'when clamdscan detects a virus' do
      let(:exitstatus) { 1 }
      let(:output) { "#{file_path}: Eicar-Test-Signature FOUND" }

      it "raises InfectedFile exception with the output message" do
        expect {
          scanner.scan(file_path)
        }.to raise_error(VirusScanner::InfectedFile, output)
      end
    end

    context 'when clamdscan fails' do
      let(:exitstatus) { 2 }
      let(:output) { "ERROR: Can't access file #{file_path}" }

      it "raises Error exception with the output message" do
        expect {
          scanner.scan(file_path)
        }.to raise_error(VirusScanner::Error, output)
      end
    end
  end
end
