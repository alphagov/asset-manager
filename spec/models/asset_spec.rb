require "spec_helper"

describe Asset do
  describe "creating an asset" do
    it "should be valid given a file" do
      a = Asset.new(:file => load_fixture_file("asset.png"))
      a.should be_valid
    end

    it "should not be valid without a file" do
      a = Asset.new(:file => nil)
      a.should_not be_valid
    end

    it "should be persisted" do
      CarrierWave::Mount::Mounter.any_instance.should_receive(:store!)

      a = Asset.new(:file => load_fixture_file("asset.png"))
      a.save

      a.should be_persisted
    end
  end

  describe "virus_scanning the attached file" do
    before :each do
      @asset = FactoryGirl.create(:asset)
    end

    it "should call out to the VirusScanner to scan the file" do
      scanner = stub("VirusScanner")
      VirusScanner.should_receive(:new).with(@asset.file.path).and_return(scanner)
      scanner.should_receive(:clean?).and_return(true)

      @asset.scan_for_viruses
    end

    it "should set the state to clean if the file is clean" do
      VirusScanner.any_instance.stub(:clean?).and_return(true)

      @asset.scan_for_viruses

      @asset.reload
      @asset.state.should == 'clean'
    end

    it "should set the state to infected if a virus is found" do
      VirusScanner.any_instance.stub(:clean?).and_return(false)

      @asset.scan_for_viruses

      @asset.reload
      @asset.state.should == 'infected'
    end

    it "should not change the state, and raise an error if there is an error scanning" do
      VirusScanner.any_instance.stub(:clean?).and_raise(VirusScanner::Error.new("Boom!"))

      lambda do
        @asset.scan_for_viruses
      end.should raise_error(VirusScanner::Error, "Boom!")

      @asset.reload
      @asset.state.should == "unscanned"
    end
  end
end
