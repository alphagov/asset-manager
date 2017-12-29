require 'spec_helper'
require 'virus_scanner'

RSpec.describe VirusScanner do
  describe "scanning a file" do
    subject(:scanner) { described_class.new }

    let(:file_path) { '/path/to/file' }

    it "calls out to clamdscan" do
      status = double("Process::Status", exitstatus: 0)
      expect(Open3).to receive(:capture2e).with("govuk_clamscan", "--no-summary", file_path).and_return(["", status])

      scanner.scan(file_path)
    end

    it "returns true if clamdscan detects no virus" do
      status = double("Process::Status", exitstatus: 0)
      allow(Open3).to receive(:capture2e).and_return(["#{file_path}: OK", status])

      expect(scanner.scan(file_path)).to eq(true)
    end

    it "returns false if clamdscan detects a virus" do
      status = double("Process::Status", exitstatus: 1)
      allow(Open3).to receive(:capture2e).and_return(["#{file_path}: Eicar-Test-Signature FOUND", status])

      expect(scanner.scan(file_path)).to eq(false)
    end

    it "makes virus info available after detecting a virus" do
      status = double("Process::Status", exitstatus: 1)
      allow(Open3).to receive(:capture2e).and_return(["#{file_path}: Eicar-Test-Signature FOUND", status])

      scanner.scan(file_path)
      expect(scanner.virus_info).to eq("#{file_path}: Eicar-Test-Signature FOUND")
    end

    it "raises an error with the output message if clamdscan fails" do
      status = double("Process::Status", exitstatus: 2)
      allow(Open3).to receive(:capture2e).and_return(["ERROR: Can't access file #{file_path}", status])

      expect {
        scanner.scan(file_path)
      }.to raise_error(VirusScanner::Error, "ERROR: Can't access file #{file_path}")
    end
  end
end
