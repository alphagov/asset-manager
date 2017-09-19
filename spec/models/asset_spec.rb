require "rails_helper"

RSpec.describe Asset, type: :model do
  include DelayedJobHelpers

  describe "creating an asset" do
    it "is valid given a file" do
      a = Asset.new(file: load_fixture_file("asset.png"))
      expect(a).to be_valid
    end

    it "is not valid without a file" do
      a = Asset.new(file: nil)
      expect(a).not_to be_valid
    end

    it "is not valid without an organisation id if it is access limited" do
      expect(Asset.new(file: load_fixture_file("asset.png"))).to be_valid
      expect(Asset.new(file: load_fixture_file("asset.png"), organisation_slug: 'example-organisation')).to be_valid
      expect(Asset.new(file: load_fixture_file("asset.png"), access_limited: true)).not_to be_valid
      expect(Asset.new(file: load_fixture_file("asset.png"), access_limited: true, organisation_slug: 'example-organisation')).to be_valid
    end

    it "is persisted" do
      expect_any_instance_of(CarrierWave::Mount::Mounter).to receive(:store!)

      a = Asset.new(file: load_fixture_file("asset.png"))
      a.save

      expect(a).to be_persisted
    end
  end

  describe '#uuid' do
    it 'is generated on instantiation' do
      allow(SecureRandom).to receive(:uuid).and_return('uuid')
      asset = Asset.new
      expect(asset.uuid).to eq('uuid')
    end

    it 'cannot be changed after creation' do
      uuid = '11111111-1111-1111-1111-11111111111111'
      asset = FactoryGirl.create(:asset, uuid: uuid)
      asset.uuid = '22222222-2222-2222-2222-222222222222'
      asset.save!
      expect(asset.reload.uuid).to eq(uuid)
    end

    it 'cannot be empty' do
      asset = FactoryGirl.build(:asset, uuid: '')
      expect(asset).not_to be_valid
      expect(asset.errors[:uuid]).to include("can't be blank")
    end

    it 'must be unique' do
      uuid = '11111111-1111-1111-1111-11111111111111'
      FactoryGirl.create(:asset, uuid: uuid)
      asset = FactoryGirl.build(:asset, uuid: uuid)
      expect(asset).not_to be_valid
      expect(asset.errors[:uuid]).to include("is already taken")
    end

    it 'must be in the format defined in rfc4122' do
      asset = FactoryGirl.build(:asset, uuid: 'uuid')
      expect(asset).not_to be_valid
      expect(asset.errors[:uuid]).to include('must match the format defined in rfc4122')
    end
  end

  describe 'validation' do
    subject(:asset) { FactoryGirl.build(:asset) }

    context 'when legacy_url_path is not set' do
      it 'is valid' do
        expect(asset).to be_valid
      end

      context 'and legacy_url_path is not unique' do
        let(:existing_asset) { FactoryGirl.create(:asset, legacy_url_path: nil) }

        before do
          asset.legacy_url_path = existing_asset.legacy_url_path
        end

        it 'is valid' do
          expect(asset).to be_valid
        end
      end
    end

    context 'when legacy_url_path is set' do
      context 'and legacy_url_path starts with /government/uploads' do
        before do
          asset.legacy_url_path = '/government/uploads/asset.png'
        end

        it 'is valid' do
          expect(asset).to be_valid
        end
      end

      context 'and legacy_url_path does not start with /government/uploads' do
        before do
          asset.legacy_url_path = '/not-government/uploads/asset.png'
        end

        it 'is not valid' do
          expect(asset).not_to be_valid
          expect(asset.errors[:legacy_url_path]).to include('must start with /government/uploads')
        end
      end

      context 'and legacy_url_path is not unique' do
        let(:valid_path) { '/government/uploads/asset.png' }
        let(:existing_asset) { FactoryGirl.create(:asset, legacy_url_path: valid_path) }

        before do
          asset.legacy_url_path = existing_asset.legacy_url_path
        end

        it 'is not valid' do
          expect(asset).not_to be_valid
          expect(asset.errors[:legacy_url_path]).to include('is already taken')
        end
      end
    end
  end

  describe '#legacy_url_path' do
    subject(:asset) { FactoryGirl.build(:asset) }

    before do
      asset.legacy_url_path = '/government/uploads/asset.png'
      asset.save!
    end

    context 'when creating asset' do
      it 'can be set' do
        expect(asset.reload.legacy_url_path).to eq('/government/uploads/asset.png')
      end
    end

    context 'when updating asset' do
      it 'cannot be set' do
        asset.legacy_url_path = '/government/uploads/another-asset.png'
        asset.save!
        expect(asset.reload.legacy_url_path).to eq('/government/uploads/asset.png')
      end
    end
  end

  describe '#public_url_path' do
    subject(:asset) { Asset.new }

    context 'when legacy_url_path is not set' do
      it 'returns public URL path for mainstream asset' do
        expected_path = "/media/#{asset.id}/#{asset.filename}"
        expect(asset.public_url_path).to eq(expected_path)
      end
    end

    context 'when legacy_url_path is set' do
      before do
        asset.legacy_url_path = '/legacy-url-path'
      end

      it 'returns legacy URL path for whitehall asset' do
        expect(asset.public_url_path).to eq('/legacy-url-path')
      end
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
    it "schedules a scan after create" do
      a = Asset.new(file: load_fixture_file("asset.png"))
      expect {
        a.save!
      }.to change(Delayed::Job, :count).by(1)

      expect(most_recently_enqueued_job).to have_payload(a)
      expect(most_recently_enqueued_job).to have_method_name(:scan_for_viruses)
    end

    it "schedules a scan after save if the file is changed" do
      a = FactoryGirl.create(:clean_asset)
      a.file = load_fixture_file("lorem.txt")
      expect {
        a.save!
      }.to change(Delayed::Job, :count).by(1)

      expect(most_recently_enqueued_job).to have_payload(a)
      expect(most_recently_enqueued_job).to have_method_name(:scan_for_viruses)
    end

    it "schedules a scan after save if the file is changed even if filename is unchanged" do
      a = FactoryGirl.create(:clean_asset)
      original_filename = a.file.send(:original_filename)
      a.file = load_fixture_file("lorem.txt", named: original_filename)
      expect {
        a.save!
      }.to change(Delayed::Job, :count).by(1)

      expect(most_recently_enqueued_job).to have_payload(a)
      expect(most_recently_enqueued_job).to have_method_name(:scan_for_viruses)
    end

    it "does not schedule a scan after update if the file is unchanged" do
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

      expect(most_recently_enqueued_job).to have_payload(asset)
      expect(most_recently_enqueued_job).to have_method_name(:save_to_cloud_storage)
    end
  end

  describe "#save_to_cloud_storage" do
    let(:asset) { FactoryGirl.create(:clean_asset) }

    context 'when S3 bucket is configured' do
      let(:cloud_storage) { double(:cloud_storage) }

      before do
        allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
      end

      it 'saves the asset to cloud storage' do
        expect(cloud_storage).to receive(:save).with(asset)

        asset.save_to_cloud_storage
      end

      context 'when an exception is raised' do
        let(:exception_class) { Class.new(StandardError) }
        let(:exception) { exception_class.new }

        before do
          allow(cloud_storage).to receive(:save).and_raise(exception)
        end

        it 'reports the exception to Errbit via Airbrake' do
          expect(Airbrake).to receive(:notify_or_ignore)
            .with(exception, params: { id: asset.id, filename: asset.filename })

          asset.save_to_cloud_storage rescue exception_class
        end

        it 're-raises the exception so Delayed::Job will re-try it' do
          allow(Airbrake).to receive(:notify_or_ignore)

          expect {
            asset.save_to_cloud_storage
          }.to raise_error(exception)
        end
      end
    end

    context 'when S3 bucket is not configured' do
      before do
        allow(AssetManager).to receive(:aws_s3_bucket_name).and_return(nil)
      end

      it 'does not attempt to build AWS S3 resource', disable_cloud_storage_stub: true do
        expect(Aws::Resources::Resource).not_to receive(:new)

        asset.save_to_cloud_storage
      end
    end
  end

  describe "virus_scanning the attached file" do
    let(:asset) { FactoryGirl.create(:asset) }

    it "calls out to the VirusScanner to scan the file" do
      scanner = double("VirusScanner")
      expect(VirusScanner).to receive(:new).with(asset.file.path).and_return(scanner)
      expect(scanner).to receive(:clean?).and_return(true)

      asset.scan_for_viruses
    end

    it "sets the state to clean if the file is clean" do
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

      it "sets the state to infected if a virus is found" do
        asset.scan_for_viruses

        asset.reload
        expect(asset.state).to eq('infected')
      end

      it "sends an exception notification" do
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

      it "does not change the state, and pass through the error if there is an error scanning" do
        expect {
          asset.scan_for_viruses
        }.to raise_error(VirusScanner::Error, "Boom!")

        asset.reload
        expect(asset.state).to eq("unscanned")
      end

      it "sends an exception notification" do
        expect(Airbrake).to receive(:notify_or_ignore).
          with(error, params: { id: asset.id, filename: asset.filename })

        asset.scan_for_viruses rescue VirusScanner::Error
      end
    end
  end

  describe "#accessible_by?(user)" do
    let(:user) { FactoryGirl.build(:user, organisation_slug: 'example-organisation') }

    it "is always true if the asset is not access limited" do
      expect(Asset.new(access_limited: false)).to be_accessible_by(user)
      expect(Asset.new(access_limited: false)).to be_accessible_by(nil)
      asset = Asset.new(access_limited: false, organisation_slug: (user.organisation_slug + "-2"))
      expect(asset).to be_accessible_by(user)
    end

    it "is true if the asset is access limited and the user has the correct organisation" do
      asset = Asset.new(access_limited: true, organisation_slug: user.organisation_slug)
      expect(asset).to be_accessible_by(user)
    end

    it "is false if the asset is access limited and the user has an incorrect organisation" do
      asset = Asset.new(access_limited: true, organisation_slug: (user.organisation_slug + "-2"))
      expect(asset).not_to be_accessible_by(user)
    end

    it "is false if the asset is access limited and the user has no organisation" do
      unassociated_user = FactoryGirl.build(:user, organisation_slug: nil)
      asset = Asset.new(access_limited: true, organisation_slug: user.organisation_slug)
      expect(asset).not_to be_accessible_by(unassociated_user)
    end

    it "is false if the asset is access limited and the user is not logged in" do
      asset = Asset.new(access_limited: true, organisation_slug: user.organisation_slug)
      expect(asset).not_to be_accessible_by(nil)
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

  describe "extension" do
    context "when asset file has extension" do
      let(:asset) { Asset.new(file: load_fixture_file("asset.png")) }

      it "returns asset file extension" do
        expect(asset.extension).to eq('png')
      end
    end

    context "when asset file has capitalised extension" do
      let(:asset) { Asset.new(file: load_fixture_file("asset-with-capitalised-extension.TXT")) }

      it "returns downcased extension" do
        expect(asset.extension).to eq('txt')
      end
    end

    context "when asset file has no extension" do
      let(:asset) { Asset.new(file: load_fixture_file("asset-without-extension")) }

      it "returns empty string" do
        expect(asset.extension).to eq('')
      end
    end
  end

  describe "content_type" do
    context "when asset file has extension" do
      context 'and the extension is a recognised mime type' do
        let(:asset) { Asset.new(file: load_fixture_file("asset.png")) }

        it "returns content type based on asset file extension" do
          expect(asset.content_type).to eq(Mime::Type.lookup('image/png').to_s)
        end
      end

      context 'and the extension is not a recognised mime type' do
        let(:asset) { Asset.new(file: load_fixture_file("asset-with-unregistered-mimetype-extension.doc")) }

        it "returns default content type" do
          expect(asset.content_type).to eq('application/octet-stream')
        end
      end
    end

    context "when asset file has no extension" do
      let(:asset) { Asset.new(file: load_fixture_file("asset-without-extension")) }

      it "returns default content type" do
        expect(asset.content_type).to eq('application/octet-stream')
      end
    end
  end

  describe '#image?' do
    let(:asset) { Asset.new }

    before do
      allow(asset).to receive(:extension).and_return(extension)
    end

    context 'when asset is an image' do
      let(:extension) { 'png' }

      it 'returns a truth-y value' do
        expect(asset).to be_image
      end
    end

    context 'when asset is not an image' do
      let(:extension) { 'pdf' }

      it 'returns a false-y value' do
        expect(asset).not_to be_image
      end
    end
  end

  describe "#etag" do
    let!(:asset) { Asset.new(file: load_fixture_file("asset.png")) }

    let(:size) { 1024 }
    let(:mtime) { Time.zone.parse('2017-01-01') }
    let(:stat) { instance_double(File::Stat, size: size, mtime: mtime) }

    before do
      allow(File).to receive(:stat).and_return(stat)
    end

    it "returns string made up of 2 parts separated by a hyphen" do
      parts = asset.etag.split('-')
      expect(parts.length).to eq(2)
    end

    it "has 1st part as file mtime (unix time in seconds written in lowercase hex)" do
      last_modified_hex = asset.etag.split('-').first
      last_modified = last_modified_hex.to_i(16)
      expect(last_modified).to eq(mtime.to_i)
    end

    it "has 2nd part as file size (number of bytes written in lowercase hex)" do
      size_hex = asset.etag.split('-').last
      size = size_hex.to_i(16)
      expect(size).to eq(size)
    end
  end

  describe "#last_modified" do
    let!(:asset) { Asset.new(file: load_fixture_file("asset.png")) }

    let(:mtime) { Time.zone.parse('2017-01-01') }
    let(:stat) { instance_double(File::Stat, mtime: mtime) }

    before do
      allow(File).to receive(:stat).and_return(stat)
    end

    it "returns time file was last modified" do
      expect(asset.last_modified).to eq(mtime)
    end
  end

  describe "#md5_hexdigest" do
    let(:asset) { Asset.new(file: load_fixture_file("asset.png")) }
    let(:md5_hexdigest) { 'a0d8aa55f6db670e38a14962c0652776' }

    it "returns MD5 hex digest for asset file content" do
      expect(asset.md5_hexdigest).to eq(md5_hexdigest)
    end
  end
end
