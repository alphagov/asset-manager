require "rails_helper"

RSpec.describe Asset, type: :model do
  describe 'validation' do
    subject(:asset) { FactoryBot.build(:asset) }

    it 'is valid when built from factory' do
      expect(asset).to be_valid
    end

    context 'when file is not specified' do
      subject(:asset) { FactoryBot.build(:asset, file: nil) }

      it 'is not valid' do
        expect(asset).not_to be_valid
      end

      context 'when asset has been uploaded to cloud storage' do
        before do
          asset.state = 'uploaded'
        end

        it 'is valid' do
          expect(asset).to be_valid
        end
      end
    end

    it 'is valid without an organisation slug' do
      asset.organisation_slug = nil
      expect(asset).to be_valid
    end

    context 'when access-limited' do
      subject(:asset) { FactoryBot.build(:access_limited_asset) }

      it 'is valid when built from factory' do
        expect(asset).to be_valid
      end

      it 'is not valid without an organisation slug' do
        asset.organisation_slug = nil
        expect(asset).not_to be_valid
      end
    end
  end

  describe 'creation' do
    subject(:asset) { FactoryBot.build(:asset) }

    before do
      asset.save!
    end

    it 'is persisted' do
      expect(asset).to be_persisted
    end

    it 'writes file to filesystem' do
      expect(File.exist?(asset.file.path)).to be_truthy
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
      asset = FactoryBot.create(:asset, uuid: uuid)
      expect { asset.uuid = '22222222-2222-2222-2222-222222222222' }.to raise_error(Mongoid::Errors::ReadonlyAttribute)
    end

    it 'cannot be empty' do
      asset = FactoryBot.build(:asset, uuid: '')
      expect(asset).not_to be_valid
      expect(asset.errors[:uuid]).to include("can't be blank")
    end

    it 'must be unique' do
      uuid = '11111111-1111-1111-1111-11111111111111'
      FactoryBot.create(:asset, uuid: uuid)
      asset = FactoryBot.build(:asset, uuid: uuid)
      expect(asset).not_to be_valid
      expect(asset.errors[:uuid]).to include("is already taken")
    end

    it 'must be in the format defined in rfc4122' do
      asset = FactoryBot.build(:asset, uuid: 'uuid')
      expect(asset).not_to be_valid
      expect(asset.errors[:uuid]).to include('must match the format defined in rfc4122')
    end
  end

  describe '#public_url_path' do
    subject(:asset) { Asset.new }

    it 'returns public URL path for mainstream asset' do
      expected_path = "/media/#{asset.id}/#{asset.filename}"
      expect(asset.public_url_path).to eq(expected_path)
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

      expect(VirusScanWorker).to receive(:perform_async).with(a.id)

      a.save!
    end

    it "schedules a scan after save if the file is changed" do
      a = FactoryBot.create(:clean_asset)
      a.file = load_fixture_file("lorem.txt")

      expect(VirusScanWorker).to receive(:perform_async).with(a.id)

      a.save!
    end

    it "schedules a scan after save if the file is changed even if filename is unchanged" do
      a = FactoryBot.create(:clean_asset)
      original_filename = a.file.send(:original_filename)
      a.file = load_fixture_file("lorem.txt", named: original_filename)

      expect(VirusScanWorker).to receive(:perform_async).with(a.id)

      a.save!
    end

    it "does not schedule a scan after update if the file is unchanged" do
      a = FactoryBot.create(:clean_asset)
      a.created_at = 5.days.ago

      expect(VirusScanWorker).not_to receive(:perform_async)

      a.save!
    end
  end

  describe "when an asset is marked as clean" do
    let!(:asset) { FactoryBot.create(:asset) }

    before do
      allow(SaveToCloudStorageWorker).to receive(:perform_async)
    end

    it 'schedules saving the asset to cloud storage' do
      expect(SaveToCloudStorageWorker).to receive(:perform_async).with(asset.id)

      asset.scanned_clean
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
        let(:asset) { Asset.new(file: Tempfile.new(['file', '.unknown-extension'])) }

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

    it 'handles .jpg file extensions' do
      file = Tempfile.new(['file', '.jpg'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('image/jpeg')
    end

    it 'handles .jpeg file extensions' do
      file = Tempfile.new(['file', '.jpeg'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('image/jpeg')
    end

    it 'handles .gif file extensions' do
      file = Tempfile.new(['file', '.gif'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('image/gif')
    end

    it 'handles .png file extensions' do
      file = Tempfile.new(['file', '.png'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('image/png')
    end

    it 'handles .pdf file extensions' do
      file = Tempfile.new(['file', '.pdf'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('application/pdf')
    end

    it 'handles .csv file extensions' do
      file = Tempfile.new(['file', '.csv'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('text/csv')
    end

    it 'handles .rtf file extensions' do
      file = Tempfile.new(['file', '.rtf'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('text/rtf')
    end

    it 'handles .doc file extensions' do
      file = Tempfile.new(['file', '.doc'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('application/msword')
    end

    it 'handles .docx file extensions' do
      file = Tempfile.new(['file', '.docx'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('application/vnd.openxmlformats-officedocument.wordprocessingml.document')
    end

    it 'handles .xls file extensions' do
      file = Tempfile.new(['file', '.xls'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('application/vnd.ms-excel')
    end

    it 'handles .xlsx file extensions' do
      file = Tempfile.new(['file', '.xlsx'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
    end

    it 'handles .odt file extensions' do
      file = Tempfile.new(['file', '.odt'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('application/vnd.oasis.opendocument.text')
    end

    it 'handles .ods file extensions' do
      file = Tempfile.new(['file', '.ods'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('application/vnd.oasis.opendocument.spreadsheet')
    end

    it 'handles .svg file extensions' do
      file = Tempfile.new(['file', '.svg'])
      asset = Asset.new(file: file)
      expect(asset.content_type).to eq('image/svg+xml')
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

  describe "#etag_from_file" do
    let!(:asset) { Asset.new(file: load_fixture_file("asset.png")) }

    let(:size) { 1024 }
    let(:mtime) { Time.zone.parse('2017-01-01') }
    let(:stat) { instance_double(File::Stat, size: size, mtime: mtime) }

    before do
      allow(File).to receive(:stat).and_return(stat)
    end

    it "returns string made up of 2 parts separated by a hyphen" do
      parts = asset.etag_from_file.split('-')
      expect(parts.length).to eq(2)
    end

    it "has 1st part as file mtime (unix time in seconds written in lowercase hex)" do
      last_modified_hex = asset.etag_from_file.split('-').first
      last_modified = last_modified_hex.to_i(16)
      expect(last_modified).to eq(mtime.to_i)
    end

    it "has 2nd part as file size (number of bytes written in lowercase hex)" do
      size_hex = asset.etag_from_file.split('-').last
      size = size_hex.to_i(16)
      expect(size).to eq(size)
    end
  end

  describe "#etag" do
    let(:asset) { Asset.new(file: load_fixture_file("asset.png"), etag: etag) }

    before do
      allow(asset).to receive(:etag_from_file).and_return('etag-from-file')
    end

    context "when asset is created" do
      let(:etag) { nil }

      before do
        asset.save!
      end

      it "stores the value generated from the file in the database" do
        expect(asset.reload.etag).to eq('etag-from-file')
      end

      context "when asset is updated with new file" do
        let(:new_file) { load_fixture_file("asset2.jpg") }

        before do
          allow(asset).to receive(:etag_from_file).and_return('etag-from-new-file')
          asset.update_attributes!(file: new_file)
        end

        it "stores the value generated from the new file in the database" do
          expect(asset.reload.etag).to eq('etag-from-new-file')
        end
      end
    end
  end

  describe "#etag=" do
    let(:asset) { Asset.new }

    it "cannot be called from outside the Asset class" do
      expect { asset.etag = 'etag-value' }.to raise_error(NoMethodError)
    end
  end

  describe "#last_modified_from_file" do
    let!(:asset) { Asset.new(file: load_fixture_file("asset.png")) }

    let(:mtime) { Time.zone.parse('2017-01-01') }
    let(:stat) { instance_double(File::Stat, mtime: mtime) }

    before do
      allow(File).to receive(:stat).and_return(stat)
    end

    it "returns time file was last modified" do
      expect(asset.last_modified_from_file).to eq(mtime)
    end
  end

  describe "#last_modified" do
    let(:asset) { Asset.new(file: load_fixture_file("asset.png"), last_modified: last_modified) }

    let(:time) { Time.parse('2002-02-02 02:02') }
    let(:time_from_file) { Time.parse('2001-01-01 01:01') }

    before do
      allow(asset).to receive(:last_modified_from_file).and_return(time_from_file)
    end

    context "when asset is created" do
      let(:last_modified) { nil }

      before do
        asset.save!
      end

      it "stores the value generated from the file in the database" do
        expect(asset.reload.last_modified).to eq(time_from_file)
      end

      context "when asset is updated with new file" do
        let(:new_file) { load_fixture_file("asset2.jpg") }
        let(:time_from_new_file) { Time.parse('2003-03-03 03:03') }

        before do
          allow(asset).to receive(:last_modified_from_file).and_return(time_from_new_file)
          asset.update_attributes!(file: new_file)
        end

        it "stores the value generated from the new file in the database" do
          expect(asset.reload.last_modified).to eq(time_from_new_file)
        end
      end
    end
  end

  describe "#last_modified=" do
    let(:asset) { Asset.new }

    it "cannot be called from outside the Asset class" do
      expect { asset.last_modified = Time.now }.to raise_error(NoMethodError)
    end
  end

  describe "#md5_hexdigest_from_file" do
    let(:asset) { Asset.new(file: load_fixture_file("asset.png")) }
    let(:md5_hexdigest) { 'a0d8aa55f6db670e38a14962c0652776' }

    it "returns MD5 hex digest for asset file content" do
      expect(asset.md5_hexdigest_from_file).to eq(md5_hexdigest)
    end
  end

  describe "#md5_hexdigest" do
    let(:asset) { Asset.new(file: load_fixture_file("asset.png"), md5_hexdigest: md5_hexdigest) }

    before do
      allow(asset).to receive(:md5_hexdigest_from_file).and_return('md5-from-file')
    end

    context "when asset is created" do
      let(:md5_hexdigest) { nil }

      before do
        asset.save!
      end

      it "stores the value generated from the file in the database" do
        expect(asset.reload.md5_hexdigest).to eq('md5-from-file')
      end

      context "when asset is updated with new file" do
        let(:new_file) { load_fixture_file("asset2.jpg") }

        before do
          allow(asset).to receive(:md5_hexdigest_from_file).and_return('md5-from-new-file')
          asset.update_attributes!(file: new_file)
        end

        it "stores the value generated from the new file in the database" do
          expect(asset.reload.md5_hexdigest).to eq('md5-from-new-file')
        end
      end
    end
  end

  describe "#md5_hexdigest=" do
    let(:asset) { Asset.new }

    it "cannot be called from outside the Asset class" do
      expect { asset.md5_hexdigest = 'md5-value' }.to raise_error(NoMethodError)
    end
  end

  describe '#mainstream?' do
    let(:asset) { Asset.new }

    it 'returns truth-y' do
      expect(asset).to be_mainstream
    end
  end

  describe '#upload_success!' do
    context 'when asset is unscanned' do
      let(:asset) { FactoryBot.create(:asset) }

      it 'does not allow asset state change to uploaded' do
        expect { asset.upload_success! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end

    context 'when asset is clean' do
      let(:asset) { FactoryBot.create(:clean_asset) }
      let(:path) { asset.file.path }

      it 'changes asset state to uploaded' do
        asset.upload_success!

        expect(asset.reload).to be_uploaded
      end

      it 'sets file attribute to blank' do
        asset.upload_success!

        expect(asset.reload.file).to be_blank
      end

      it 'removes the underlying file' do
        asset.upload_success!

        expect(File.exist?(path)).to be_falsey
      end
    end

    context 'when asset is infected' do
      let(:asset) { FactoryBot.create(:infected_asset) }

      it 'does not allow asset state change to uploaded' do
        expect { asset.upload_success! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end

    context 'when asset is uploaded' do
      let(:asset) { FactoryBot.create(:uploaded_asset) }

      it 'does not allow asset state change to uploaded' do
        expect { asset.upload_success! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end
  end

  describe '#save' do
    let(:asset) { FactoryBot.create(:clean_asset) }

    context 'when asset has been uploaded to cloud storage' do
      before do
        asset.upload_success!
      end

      it 'saves asset successfully despite having no file' do
        expect(asset.save).to be_truthy
      end
    end
  end
end
