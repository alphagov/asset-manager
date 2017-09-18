require 'spec_helper'
require 'virus_scanner'

RSpec.describe VirusScanner do
  describe "scanning a file" do
    subject(:scanner) { described_class.new("/path/to/file") }

    it "calls out to clamdscan" do
      status = double("Process::Status", exitstatus: 0)
      expect(Open3).to receive(:capture2e).with("govuk_clamscan", "--no-summary", "/path/to/file").and_return(["", status])

      scanner.clean?
    end

    it "only scans the file once" do
      status = double("Process::Status", exitstatus: 0)
      allow(Open3).to receive(:capture2e).and_return(["/path/to/file: OK", status])

      scanner.clean?
      expect(Open3).not_to receive(:capture2e)

      expect(scanner.clean?).to eq(true)
    end

    it "returns true if clamdscan detects no virus" do
      status = double("Process::Status", exitstatus: 0)
      allow(Open3).to receive(:capture2e).and_return(["/path/to/file: OK", status])

      expect(scanner.clean?).to eq(true)
    end

    it "returns false if clamdscan detects a virus" do
      status = double("Process::Status", exitstatus: 1)
      allow(Open3).to receive(:capture2e).and_return(["/path/to/file: Eicar-Test-Signature FOUND", status])

      expect(scanner.clean?).to eq(false)
    end

    it "makes virus info available after detecting a virus" do
      status = double("Process::Status", exitstatus: 1)
      allow(Open3).to receive(:capture2e).and_return(["/path/to/file: Eicar-Test-Signature FOUND", status])

      scanner.clean?
      expect(scanner.virus_info).to eq("/path/to/file: Eicar-Test-Signature FOUND")
    end

    it "raises an error with the output message if clamdscan fails" do
      status = double("Process::Status", exitstatus: 2)
      allow(Open3).to receive(:capture2e).and_return(["ERROR: Can't access file /path/to/file", status])

      expect {
        scanner.clean?
      }.to raise_error(VirusScanner::Error, "ERROR: Can't access file /path/to/file")
    end
  end
end
