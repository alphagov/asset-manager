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

    it "should not be valid without an organisation id if it is access limited" do
      Asset.new(:file => load_fixture_file("asset.png")).should be_valid
      Asset.new(:file => load_fixture_file("asset.png"), :organisation_slug => 'example-organisation').should be_valid
      Asset.new(:file => load_fixture_file("asset.png"), :access_limited => true).should_not be_valid
      Asset.new(:file => load_fixture_file("asset.png"), :access_limited => true, :organisation_slug => 'example-organisation').should be_valid
    end

    it "should be persisted" do
      CarrierWave::Mount::Mounter.any_instance.should_receive(:store!)

      a = Asset.new(:file => load_fixture_file("asset.png"))
      a.save

      a.should be_persisted
    end
  end

  describe "#filename" do
    let(:asset) {
      Asset.new(:file => load_fixture_file("asset.png"))
    }

    it "returns the current file attachments base name" do
      expect(asset.filename).to eq("asset.png")
    end
  end

  describe "#filename_valid?" do
    let(:asset) {
      Asset.new(:file => load_fixture_file("asset.png"))
    }

    context "for current file" do
      it "returns true" do
        expect(asset.filename_valid?("asset.png")).to be_true
      end
    end

    context "for a previous file name" do
      before do
        asset.file = load_fixture_file("asset2.jpg")
      end

      it "returns true" do
        expect(asset.filename_valid?("asset.png")).to be_true
      end
    end

    context "for a file that has never been attached to the asset" do
      it "returns false" do
        expect(asset.filename_valid?("never_existed.png")).to be_false
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
        Airbrake.should_receive(:notify_or_ignore).
          with(VirusScanner::InfectedFile.new, :error_message => "/path/to/file: Eicar-Test-Signature FOUND", :params => {:id => @asset.id, :filename => @asset.filename})

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
        Airbrake.should_receive(:notify_or_ignore).
          with(@error, :params => {:id => @asset.id, :filename => @asset.filename})

        begin
          @asset.scan_for_viruses
        rescue VirusScanner::Error
          # Swallow the passed through exception
        end
      end
    end
  end

  describe "#accessible_by?(user)" do
    before(:all) do
      @user = FactoryGirl.build(:user, organisation_slug: 'example-organisation')
    end

    it "is always true if the asset is not access limited" do
      Asset.new(access_limited: false).accessible_by?(@user).should be_true
      Asset.new(access_limited: false).accessible_by?(nil).should be_true
      asset = Asset.new(access_limited: false, organisation_slug: (@user.organisation_slug + "-2"))
      asset.accessible_by?(@user).should be_true
    end

    it "is true if the asset is access limited and the user has the correct organisation" do
      asset = Asset.new(access_limited: true, organisation_slug: @user.organisation_slug)
      asset.accessible_by?(@user).should be_true
    end

    it "is false if the asset is access limited and the user has an incorrect organisation" do
      asset = Asset.new(access_limited: true, organisation_slug: (@user.organisation_slug + "-2"))
      asset.accessible_by?(@user).should be_false
    end

    it "is false if the asset is access limited and the user has no organisation" do
      unassociated_user = FactoryGirl.build(:user, organisation_slug: nil)
      asset = Asset.new(access_limited: true, organisation_slug: @user.organisation_slug)
      asset.accessible_by?(unassociated_user).should be_false
    end

    it "is false if the asset is access limited and the user is not logged in" do
      asset = Asset.new(access_limited: true, organisation_slug: @user.organisation_slug)
      asset.accessible_by?(nil).should be_false
    end
  end
end
