require 'spec_helper'
require 'virus_scanner'

describe VirusScanner do

  describe "scanning a file" do
    before :each do
      @scanner = VirusScanner.new("/path/to/file")
    end

    it "should call out to clamdscan" do
      status = stub("Process::Status", :exitstatus => 0)
      Open3.should_receive(:capture2e).with("clamscan", "--no-summary", "/path/to/file").and_return(["", status])

      @scanner.clean?
    end

    it "should only scan the file once" do
      status = stub("Process::Status", :exitstatus => 0)
      Open3.stub(:capture2e).and_return(["/path/to/file: OK", status])

      @scanner.clean?
      Open3.should_not_receive(:capture2e)

      @scanner.clean?.should == true
    end

    it "should return true if clamdscan detects no virus" do
      status = stub("Process::Status", :exitstatus => 0)
      Open3.stub(:capture2e).and_return(["/path/to/file: OK", status])

      @scanner.clean?.should == true
    end

    it "should return false if clamdscan detects a virus" do
      status = stub("Process::Status", :exitstatus => 1)
      Open3.stub(:capture2e).and_return(["/path/to/file: Eicar-Test-Signature FOUND", status])

      @scanner.clean?.should == false
    end

    it "should make virus info available after detecting a virus" do
      status = stub("Process::Status", :exitstatus => 1)
      Open3.stub(:capture2e).and_return(["/path/to/file: Eicar-Test-Signature FOUND", status])

      @scanner.clean?
      @scanner.virus_info.should == "/path/to/file: Eicar-Test-Signature FOUND"
    end

    it "should raise an error with the output message if clamdscan fails" do
      status = stub("Process::Status", :exitstatus => 2)
      Open3.stub(:capture2e).and_return(["ERROR: Can't access file /path/to/file", status])

      lambda do
        @scanner.clean?
      end.should raise_error(VirusScanner::Error, "ERROR: Can't access file /path/to/file")
    end
  end
end
