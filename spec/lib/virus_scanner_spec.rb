require 'spec_helper'
require 'virus_scanner'

RSpec.describe VirusScanner do
  describe "scanning a file" do
    before :each do
      @scanner = VirusScanner.new("/path/to/file")
    end

    it "should call out to clamdscan" do
      status = double("Process::Status", exitstatus: 0)
      expect(Open3).to receive(:capture2e).with("govuk_clamscan", "--no-summary", "/path/to/file").and_return(["", status])

      @scanner.clean?
    end

    it "should only scan the file once" do
      status = double("Process::Status", exitstatus: 0)
      allow(Open3).to receive(:capture2e).and_return(["/path/to/file: OK", status])

      @scanner.clean?
      expect(Open3).not_to receive(:capture2e)

      expect(@scanner.clean?).to eq(true)
    end

    it "should return true if clamdscan detects no virus" do
      status = double("Process::Status", exitstatus: 0)
      allow(Open3).to receive(:capture2e).and_return(["/path/to/file: OK", status])

      expect(@scanner.clean?).to eq(true)
    end

    it "should return false if clamdscan detects a virus" do
      status = double("Process::Status", exitstatus: 1)
      allow(Open3).to receive(:capture2e).and_return(["/path/to/file: Eicar-Test-Signature FOUND", status])

      expect(@scanner.clean?).to eq(false)
    end

    it "should make virus info available after detecting a virus" do
      status = double("Process::Status", exitstatus: 1)
      allow(Open3).to receive(:capture2e).and_return(["/path/to/file: Eicar-Test-Signature FOUND", status])

      @scanner.clean?
      expect(@scanner.virus_info).to eq("/path/to/file: Eicar-Test-Signature FOUND")
    end

    it "should raise an error with the output message if clamdscan fails" do
      status = double("Process::Status", exitstatus: 2)
      allow(Open3).to receive(:capture2e).and_return(["ERROR: Can't access file /path/to/file", status])

      expect do
        @scanner.clean?
      end.to raise_error(VirusScanner::Error, "ERROR: Can't access file /path/to/file")
    end
  end
end
