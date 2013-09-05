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

  describe "with metadata" do
    
    it "should persist all fields" do
      
      a = FactoryGirl.create(:asset_with_metadata)

      # Load from DB
      b = Asset.find(a.id)
      metadata = {
        title: "My Cat",
        source: "http://catgifs.com/42",
        description: "My cat is lovely",
        creator: "A N Other",
        subject: %w{cat kitty},
        license: "CC BY 3.0",
      }.each_pair do |key, value|
        b.send(key).should == value
      end

    end
    
  end

  describe "scheduling a virus scan" do
    it "should schedule a scan after create" do
      a = Asset.new(:file => load_fixture_file("asset.png"))
      lambda do
        a.save!
      end.should change(Delayed::Job, :count).by(1)

      job = Delayed::Job.last
      handler = YAML.load(job.handler)
      handler.object.should == a
      handler.method_name.should == :scan_for_viruses
    end

    it "should schedule a scan after save if the file is changed" do
      a = FactoryGirl.create(:clean_asset)
      a.file = load_fixture_file("lorem.txt")
      lambda do
        a.save!
      end.should change(Delayed::Job, :count).by(1)

      job = Delayed::Job.last
      handler = YAML.load(job.handler)
      handler.object.should == a
      handler.method_name.should == :scan_for_viruses
    end

    it "should not schedule a scan after update if the file is unchanged" do
      a = FactoryGirl.create(:clean_asset)
      a.created_at = 5.days.ago
      lambda do
        a.save!
      end.should_not change(Delayed::Job, :count)
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

    context "when a virus is found" do
      before :each do
        VirusScanner.any_instance.stub(:clean?).and_return(false)
        VirusScanner.any_instance.stub(:virus_info).and_return("/path/to/file: Eicar-Test-Signature FOUND")
      end

      it "should set the state to infected if a virus is found" do
        @asset.scan_for_viruses

        @asset.reload
        @asset.state.should == 'infected'
      end

      it "should send an exception notification" do
        ExceptionNotifier::Notifier.should_receive(:background_exception_notification).
          with(VirusScanner::InfectedFile.new, :data => {:virus_info => "/path/to/file: Eicar-Test-Signature FOUND"})

        @asset.scan_for_viruses
      end
    end

    context "when there is an error scanning" do
      before :each do
        @error = VirusScanner::Error.new("Boom!")
        VirusScanner.any_instance.stub(:clean?).and_raise(@error)
      end

      it "should not change the state, and pass throuth the error if there is an error scanning" do
        lambda do
          @asset.scan_for_viruses
        end.should raise_error(VirusScanner::Error, "Boom!")

        @asset.reload
        @asset.state.should == "unscanned"
      end

      it "should send an exception notification" do
        ExceptionNotifier::Notifier.should_receive(:background_exception_notification).
          with(@error)

        begin
          @asset.scan_for_viruses
        rescue VirusScanner::Error
          # Swallow the passed through exception
        end
      end
    end
  end
end
