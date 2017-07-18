require "rails_helper"

RSpec.describe Asset, type: :model do
  describe "creating an asset" do
    it "should be valid given a file" do
      a = Asset.new(file: load_fixture_file("asset.png"))
      expect(a).to be_valid
    end

    it "should not be valid without a file" do
      a = Asset.new(file: nil)
      expect(a).not_to be_valid
    end

    it "should not be valid without an organisation id if it is access limited" do
      expect(Asset.new(file: load_fixture_file("asset.png"))).to be_valid
      expect(Asset.new(file: load_fixture_file("asset.png"), organisation_slug: 'example-organisation')).to be_valid
      expect(Asset.new(file: load_fixture_file("asset.png"), access_limited: true)).not_to be_valid
      expect(Asset.new(file: load_fixture_file("asset.png"), access_limited: true, organisation_slug: 'example-organisation')).to be_valid
    end

    it "should be persisted" do
      expect_any_instance_of(CarrierWave::Mount::Mounter).to receive(:store!)

      a = Asset.new(file: load_fixture_file("asset.png"))
      a.save

      expect(a).to be_persisted
    end
  end

  describe "#filename" do
    let(:asset) {
      Asset.new(file: load_fixture_file("asset.png"))
    }

    it "returns the current file attachments base name" do
      expect(asset.filename).to eq("asset.png")
    end
  end

  describe "#filename_valid?" do
    let(:asset) {
      Asset.new(file: load_fixture_file("asset.png"))
    }

    context "for current file" do
      it "returns true" do
        expect(asset.filename_valid?("asset.png")).to be_truthy
      end
    end

    context "for a previous file name" do
      before do
        asset.file = load_fixture_file("asset2.jpg")
      end

      it "returns true" do
        expect(asset.filename_valid?("asset.png")).to be_truthy
      end
    end

    context "for a file that has never been attached to the asset" do
      it "returns false" do
        expect(asset.filename_valid?("never_existed.png")).to be_falsey
      end
    end
  end

  describe "scheduling a virus scan" do
    it "should schedule a scan after create" do
      a = Asset.new(file: load_fixture_file("asset.png"))
      expect {
        a.save!
      }.to change(Delayed::Job, :count).by(1)

      job = Delayed::Job.last
      expect(job.payload_object.object).to eq(a)
      expect(job.payload_object.method_name).to eq(:scan_for_viruses)
    end

    it "should schedule a scan after save if the file is changed" do
      a = FactoryGirl.create(:clean_asset)
      a.file = load_fixture_file("lorem.txt")
      expect {
        a.save!
      }.to change(Delayed::Job, :count).by(1)

      job = Delayed::Job.last
      expect(job.payload_object.object).to eq(a)
      expect(job.payload_object.method_name).to eq(:scan_for_viruses)
    end

    it "should not schedule a scan after update if the file is unchanged" do
      a = FactoryGirl.create(:clean_asset)
      a.created_at = 5.days.ago
      expect {
        a.save!
      }.not_to change(Delayed::Job, :count)
    end
  end

  describe "when an asset is marked as clean" do
    let!(:asset) { FactoryGirl.create(:asset) }

    before do
      allow_any_instance_of(VirusScanner).to receive(:clean?).and_return(true)
    end

    it 'schedules saving the asset to cloud storage' do
      expect {
        asset.scan_for_viruses
      }.to change(Delayed::Job, :count).by(1)

      job = Delayed::Job.last
      expect(job.payload_object.object).to eq(asset)
      expect(job.payload_object.method_name).to eq(:save_to_cloud_storage)
    end
  end

  describe "#save_to_cloud_storage" do
    let(:asset) { FactoryGirl.create(:clean_asset) }
    let(:cloud_storage) { double(:cloud_storage) }

    before do
      allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
    end

    it 'saves the asset to cloud storage' do
      expect(cloud_storage).to receive(:save).with(asset)

      asset.save_to_cloud_storage
    end
  end

  describe "virus_scanning the attached file" do
    let(:asset) { FactoryGirl.create(:asset) }

    it "should call out to the VirusScanner to scan the file" do
      scanner = double("VirusScanner")
      expect(VirusScanner).to receive(:new).with(asset.file.path).and_return(scanner)
      expect(scanner).to receive(:clean?).and_return(true)

      asset.scan_for_viruses
    end

    it "should set the state to clean if the file is clean" do
      allow_any_instance_of(VirusScanner).to receive(:clean?).and_return(true)

      asset.scan_for_viruses

      asset.reload
      expect(asset.state).to eq('clean')
    end

    context "when a virus is found" do
      before do
        allow_any_instance_of(VirusScanner).to receive(:clean?).and_return(false)
        allow_any_instance_of(VirusScanner).to receive(:virus_info).and_return("/path/to/file: Eicar-Test-Signature FOUND")
      end

      it "should set the state to infected if a virus is found" do
        asset.scan_for_viruses

        asset.reload
        expect(asset.state).to eq('infected')
      end

      it "should send an exception notification" do
        expect(Airbrake).to receive(:notify_or_ignore).
          with(VirusScanner::InfectedFile.new, error_message: "/path/to/file: Eicar-Test-Signature FOUND", params: { id: asset.id, filename: asset.filename })

        asset.scan_for_viruses
      end
    end

    context "when there is an error scanning" do
      let(:error) { VirusScanner::Error.new("Boom!") }

      before do
        allow_any_instance_of(VirusScanner).to receive(:clean?).and_raise(error)
      end

      it "should not change the state, and pass throuth the error if there is an error scanning" do
        expect {
          asset.scan_for_viruses
        }.to raise_error(VirusScanner::Error, "Boom!")

        asset.reload
        expect(asset.state).to eq("unscanned")
      end

      it "should send an exception notification" do
        expect(Airbrake).to receive(:notify_or_ignore).
          with(error, params: { id: asset.id, filename: asset.filename })

        asset.scan_for_viruses rescue VirusScanner::Error
      end
    end
  end

  describe "#accessible_by?(user)" do
    let(:user) { FactoryGirl.build(:user, organisation_slug: 'example-organisation') }

    it "is always true if the asset is not access limited" do
      expect(Asset.new(access_limited: false).accessible_by?(user)).to be_truthy
      expect(Asset.new(access_limited: false).accessible_by?(nil)).to be_truthy
      asset = Asset.new(access_limited: false, organisation_slug: (user.organisation_slug + "-2"))
      expect(asset.accessible_by?(user)).to be_truthy
    end

    it "is true if the asset is access limited and the user has the correct organisation" do
      asset = Asset.new(access_limited: true, organisation_slug: user.organisation_slug)
      expect(asset.accessible_by?(user)).to be_truthy
    end

    it "is false if the asset is access limited and the user has an incorrect organisation" do
      asset = Asset.new(access_limited: true, organisation_slug: (user.organisation_slug + "-2"))
      expect(asset.accessible_by?(user)).to be_falsey
    end

    it "is false if the asset is access limited and the user has no organisation" do
      unassociated_user = FactoryGirl.build(:user, organisation_slug: nil)
      asset = Asset.new(access_limited: true, organisation_slug: user.organisation_slug)
      expect(asset.accessible_by?(unassociated_user)).to be_falsey
    end

    it "is false if the asset is access limited and the user is not logged in" do
      asset = Asset.new(access_limited: true, organisation_slug: user.organisation_slug)
      expect(asset.accessible_by?(nil)).to be_falsey
    end
  end

  describe "soft deletion" do
    let(:asset) { Asset.new(file: load_fixture_file("asset.png")) }

    it "includes the Mongoid::Paranoia library" do
      expect(asset).to be_a(Mongoid::Paranoia)
    end

    it "adds a deleted_at timestamp to the record" do
      asset.destroy
      expect(asset.deleted_at).not_to be_nil
    end

    it "can be restored" do
      asset.destroy
      expect(asset.deleted_at).not_to be_nil
      asset.restore
      expect(asset.deleted_at).to be_nil
    end
  end
end
