require "rails_helper"

RSpec.describe Asset, type: :model do
  include Rails.application.routes.url_helpers

  describe "validation" do
    subject(:asset) { FactoryBot.build(:asset, attributes) }

    let(:attributes) { {} }

    it "is valid when built from factory" do
      expect(asset).to be_valid
    end

    context "when file is not specified" do
      let(:attributes) { { file: nil } }

      it "is not valid" do
        expect(asset).not_to be_valid
      end

      context "when asset has been uploaded to cloud storage" do
        before do
          asset.state = "uploaded"
        end

        it "is valid" do
          expect(asset).to be_valid
        end
      end
    end

    context "when replacement_id is not specified" do
      let(:attributes) { { replacement_id: nil } }

      it "is valid" do
        expect(asset).to be_valid
      end
    end

    context "when replacement_id is specified" do
      let(:attributes) { { replacement_id: } }

      context "and replacement asset exists" do
        let(:replacement) { FactoryBot.create(:asset) }
        let(:replacement_id) { replacement.id.to_s }

        it "is valid" do
          expect(asset).to be_valid
        end
      end

      context "and replacement asset does not exist" do
        let(:replacement_id) { "non-existent-asset-id" }

        it "is not valid" do
          expect(asset).not_to be_valid
        end

        it "includes error for replacement not found" do
          asset.valid?
          expect(asset.errors[:replacement]).to include("not found")
        end
      end

      context "and the replacement exists but has been deleted" do
        let(:replacement) { FactoryBot.create(:asset) }
        let(:replacement_id) { replacement.id.to_s }

        before do
          replacement.destroy
        end

        it "is valid" do
          expect(asset).to be_valid
        end
      end
    end

    context "when replacements are replaced" do
      let(:first_replacement) { FactoryBot.create(:asset, draft: false) }
      let(:second_replacement) { FactoryBot.create(:asset, draft: true) }

      before do
        asset.replacement = first_replacement
        asset.save!
        first_replacement.replacement = second_replacement
        first_replacement.save!
      end

      it "doesn't update the original asset if the second replacement is a draft" do
        expect(asset.reload.replacement_id).to eq(first_replacement.id)
      end

      it "updates the original asset when the second replacement is published" do
        second_replacement.draft = false
        second_replacement.save!
        expect(asset.reload.replacement_id).to eq(second_replacement.id)
      end
    end

    context "when published asset is marked as draft" do
      let(:replacement) { nil }
      let(:redirect_url) { nil }
      let(:attributes) do
        {
          draft: false,
          replacement:,
          redirect_url:,
        }
      end

      before do
        asset.save!
        asset.draft = true
      end

      it "is valid" do
        expect(asset).to be_valid
      end

      context "and asset is replaced" do
        let(:replacement) { FactoryBot.create(:asset) }

        it "is not valid" do
          expect(asset).not_to be_valid
        end

        it "includes error for forbidden draft state change" do
          asset.valid?
          message = "cannot be true, because already replaced"
          expect(asset.errors[:draft]).to include(message)
        end
      end

      context "and asset is redirected" do
        let(:redirect_url) { "https://example.com/path/file.ext" }

        it "is not valid" do
          expect(asset).not_to be_valid
        end

        it "includes error for forbidden draft state change" do
          asset.valid?
          message = "cannot be true, because already redirected"
          expect(asset.errors[:draft]).to include(message)
        end
      end
    end

    context "when parent_document_url is not specified" do
      it "is valid" do
        asset.parent_document_url = nil
        expect(asset).to be_valid
      end
    end

    context "when parent_document_url is specified" do
      it "is valid when it's an http URL" do
        asset.parent_document_url = "http://www.example.com"
        expect(asset).to be_valid
      end

      it "is valid when it's an https URL" do
        asset.parent_document_url = "https://www.example.com"
        expect(asset).to be_valid
      end

      context "and is not an http(s) URL" do
        before do
          asset.parent_document_url = "ftp://example.com"
        end

        it "is invalid" do
          expect(asset).not_to be_valid
        end

        it "contains error message" do
          asset.valid?
          message = "must be an http(s) URL"
          expect(asset.errors[:parent_document_url]).to include(message)
        end
      end

      context "and the URL cannot be parsed" do
        before do
          asset.parent_document_url = "http://foo:bar:baz"
        end

        it "is invalid" do
          expect(asset).not_to be_valid
        end

        it "contains error message" do
          asset.valid?
          message = "must be an http(s) URL"
          expect(asset.errors[:parent_document_url]).to include(message)
        end
      end

      context "and the URL points to the draft stack" do
        before do
          asset.parent_document_url = "https://draft-origin.publishing.service.gov.uk/government/news/test"
        end

        context "when the asset is a draft" do
          before do
            asset.draft = true
          end

          it "is valid" do
            expect(asset).to be_valid
          end
        end

        context "when the asset is published" do
          before do
            asset.draft = false
          end

          it "is invalid" do
            expect(asset).not_to be_valid
          end

          it "has the expected error message" do
            asset.valid?
            message = "must be a public GOV.UK URL"
            expect(asset.errors[:parent_document_url]).to include(message)
          end
        end
      end
    end

    context "when content_type is not specified" do
      it "is valid" do
        asset.content_type = nil
        expect(asset).to be_valid
      end
    end

    context "when content_type is specified" do
      it "accepts valid media types" do
        %w[
          text/plain
          application/atom+xml
          application/EDI-X12
          application/xml-dtd
          application/zip
          application/vnd.openxmlformats-officedocument.presentationml
          video/quicktime
          very#unusual/but&valid
        ].each do |media_type|
          asset.content_type = media_type
          expect(asset).to be_valid
        end
      end

      it "is rejects an invalid media type" do
        %w[
          */*
          application/with$invalid%characters
          text/with-parameter;parameter=123
        ].each do |media_type|
          asset.content_type = media_type
          expect(asset).not_to be_valid
        end
      end
    end
  end

  describe "creation" do
    subject(:asset) { FactoryBot.build(:asset) }

    before do
      asset.save!
    end

    it "is persisted" do
      expect(asset).to be_persisted
    end

    it "writes file to filesystem" do
      expect(File).to exist(asset.file.path)
    end
  end

  describe "#accessible_by?" do
    context "when the asset is live" do
      let(:asset) { FactoryBot.build(:asset, draft: false) }

      it "returns true" do
        expect(asset).to be_accessible_by(nil)
      end
    end

    context "when the asset is a draft thats access_limited" do
      let(:asset) do
        FactoryBot.build(
          :asset, draft: true, access_limited: %w[user-id], access_limited_organisation_ids: %w[org-id]
        )
      end

      it "returns true if user's id is authorised to view it" do
        user = FactoryBot.build(:user, uid: "user-id")
        expect(asset).to be_accessible_by(user)
      end

      it "returns false if user's id is not authorised to view it" do
        user = FactoryBot.build(:user, uid: "another-id")
        expect(asset).not_to be_accessible_by(user)
      end

      it "returns true if the user's org is authorised to view it" do
        user = FactoryBot.build(:user, uid: "another-id", organisation_content_id: "org-id")
        expect(asset).to be_accessible_by(user)
      end

      it "returns false if the user's org is not authorised to view it" do
        user = FactoryBot.build(:user, uid: "another-id", organisation_content_id: "another-org-id")
        expect(asset).not_to be_accessible_by(user)
      end
    end

    context "when the asset is a draft thats not access limited" do
      let(:asset) { FactoryBot.build(:asset, draft: true) }

      it "returns true" do
        expect(asset).to be_accessible_by(nil)
      end
    end
  end

  describe "#valid_auth_bypass_token?" do
    it "returns true when given an auth_bypass_id which is in the auth_bypass_ids" do
      asset = FactoryBot.build(:asset, auth_bypass_ids: %w[my-token])
      auth_bypass_id = "my-token"
      expect(asset.valid_auth_bypass_token?(auth_bypass_id)).to be true
    end

    it "returns false when given an auth_bypass_id which is not in the auth_bypass_ids" do
      asset = FactoryBot.build(:asset, auth_bypass_ids: %w[my-token])
      auth_bypass_id = "different-token"
      expect(asset.valid_auth_bypass_token?(auth_bypass_id)).to be false
    end
  end

  describe "#uuid" do
    it "is generated on instantiation" do
      allow(SecureRandom).to receive(:uuid).and_return("uuid")
      asset = described_class.new
      expect(asset.uuid).to eq("uuid")
    end

    it "cannot be changed after creation" do
      uuid = "11111111-1111-1111-1111-11111111111111"
      asset = FactoryBot.create(:asset, uuid:)
      expect { asset.uuid = "22222222-2222-2222-2222-222222222222" }
        .not_to change(asset, :uuid)
    end

    it "cannot be empty" do
      asset = FactoryBot.build(:asset, uuid: "")
      expect(asset).not_to be_valid
      expect(asset.errors[:uuid]).to include("can't be blank")
    end

    it "must be unique" do
      uuid = "11111111-1111-1111-1111-11111111111111"
      FactoryBot.create(:asset, uuid:)
      asset = FactoryBot.build(:asset, uuid:)
      expect(asset).not_to be_valid
      expect(asset.errors[:uuid]).to include("has already been taken")
    end

    it "must be in the format defined in rfc4122" do
      asset = FactoryBot.build(:asset, uuid: "uuid")
      expect(asset).not_to be_valid
      expect(asset.errors[:uuid]).to include("must match the format defined in rfc4122")
    end
  end

  describe "#draft?" do
    subject(:asset) { described_class.new }

    it "returns false-y by default" do
      expect(asset).not_to be_draft
    end

    context "when draft attribute is set to false" do
      subject(:asset) { described_class.new(draft: false) }

      it "returns false-y by default" do
        expect(asset).not_to be_draft
      end
    end

    context "when draft attribute is set to true" do
      subject(:asset) { described_class.new(draft: true) }

      it "returns truth-y by default" do
        expect(asset).to be_draft
      end
    end
  end

  describe "#public_url_path" do
    subject(:asset) do
      described_class.new(file: load_fixture_file("asset.png"))
    end

    it "returns public URL path for asset" do
      expected_path = download_media_path(id: asset.id, filename: asset.filename)
      expect(asset.public_url_path).to eq(expected_path)
    end
  end

  describe "#filename" do
    let(:asset) do
      described_class.new(file: load_fixture_file("asset.png"))
    end

    it "returns the current file attachments base name" do
      expect(asset.filename).to eq("asset.png")
    end
  end

  describe "#filename_valid?" do
    let(:asset) do
      described_class.new(file: load_fixture_file("asset.png"))
    end

    context "with current file" do
      it "returns true" do
        expect(asset).to be_filename_valid("asset.png")
      end
    end

    context "with a previous file name" do
      before do
        asset.file = load_fixture_file("asset2.jpg")
      end

      it "returns true" do
        expect(asset).to be_filename_valid("asset.png")
      end
    end

    context "with a file that has never been attached to the asset" do
      it "returns false" do
        expect(asset).not_to be_filename_valid("never_existed.png")
      end
    end
  end

  describe "scheduling a virus scan" do
    it "schedules a scan after create" do
      a = described_class.new(file: load_fixture_file("asset.png"))

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

    it "does not schedule a scan if a redirect url is present" do
      a = FactoryBot.create(:asset, redirect_url: "/some-redirect")

      expect(VirusScanWorker).not_to receive(:perform_async)

      a.save!
    end
  end

  describe "when an asset is marked as clean" do
    let(:state) { "unscanned" }
    let(:asset) { FactoryBot.build(:asset, state:) }

    before do
      allow(SaveToCloudStorageWorker).to receive(:perform_async)
    end

    it "sets the asset state to clean" do
      asset.scanned_clean!

      expect(asset.reload).to be_clean
    end

    it "schedules saving the asset to cloud storage" do
      expect(SaveToCloudStorageWorker).to receive(:perform_async).with(asset.id)

      asset.scanned_clean!
    end

    context "when asset is already clean" do
      let(:state) { "clean" }

      it "does not allow the state transition" do
        expect { asset.scanned_clean! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end

    context "when asset is already infected" do
      let(:state) { "infected" }

      it "does not allow the state transition" do
        expect { asset.scanned_clean! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end

    context "when asset is already uploaded" do
      let(:state) { "uploaded" }

      it "does not allow the state transition" do
        expect { asset.scanned_clean! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end
  end

  describe "when an asset is marked as infected" do
    let(:state) { "unscanned" }
    let(:asset) { FactoryBot.build(:asset, state:) }

    it "does not schedule saving the asset to cloud storage" do
      expect(SaveToCloudStorageWorker).not_to receive(:perform_async).with(asset.id)

      asset.scanned_infected!
    end

    it "sets the asset state to infected" do
      asset.scanned_infected!

      expect(asset.reload).to be_infected
    end

    context "when asset is clean" do
      let(:state) { "clean" }

      it "does not allow the state transition" do
        expect { asset.scanned_infected! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end

    context "when asset is already infected" do
      let(:state) { "infected" }

      it "does not allow the state transition" do
        expect { asset.scanned_infected! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end

    context "when asset is already uploaded" do
      let(:state) { "uploaded" }

      it "does not allow the state transition" do
        expect { asset.scanned_infected! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end
  end

  describe "soft deletion" do
    let(:asset) { described_class.new(file: load_fixture_file("asset.png")) }

    before do
      asset.destroy
    end

    it "adds a deleted_at timestamp to the record" do
      expect(asset.deleted_at).not_to be_nil
    end

    it "is not inclued in the 'undeleted' scope" do
      expect(described_class.undeleted).not_to include(asset)
    end

    it "is included in the 'deleted' scope" do
      expect(described_class.deleted).to include(asset)
    end

    it "can be restored" do
      asset.destroy!
      expect(asset.deleted_at).not_to be_nil
      asset.restore
      expect(asset.deleted_at).to be_nil
    end
  end

  describe "extension" do
    context "when asset file has extension" do
      let(:asset) { described_class.new(file: load_fixture_file("asset.png")) }

      it "returns asset file extension" do
        expect(asset.extension).to eq("png")
      end
    end

    context "when asset file has capitalised extension" do
      let(:asset) { described_class.new(file: load_fixture_file("asset-with-capitalised-extension.TXT")) }

      it "returns downcased extension" do
        expect(asset.extension).to eq("txt")
      end
    end

    context "when asset file has no extension" do
      let(:asset) { described_class.new(file: load_fixture_file("asset-without-extension")) }

      it "returns empty string" do
        expect(asset.extension).to eq("")
      end
    end
  end

  describe "content_type_from_extension" do
    context "when asset file has extension" do
      context "and the extension is a recognised mime type" do
        let(:asset) { described_class.new(file: load_fixture_file("asset.png")) }

        it "returns content type based on asset file extension" do
          expect(asset.content_type_from_extension).to eq(Mime::Type.lookup("image/png").to_s)
        end
      end

      context "and the extension is not a recognised mime type" do
        let(:asset) { described_class.new(file: Tempfile.new(["file", ".unknown-extension"])) }

        it "returns default content type" do
          expect(asset.content_type_from_extension).to eq("application/octet-stream")
        end
      end
    end

    context "when asset file has no extension" do
      let(:asset) { described_class.new(file: load_fixture_file("asset-without-extension")) }

      it "returns default content type" do
        expect(asset.content_type_from_extension).to eq("application/octet-stream")
      end
    end

    it "handles .jpg file extensions" do
      file = Tempfile.new(["file", ".jpg"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("image/jpeg")
    end

    it "handles .jpeg file extensions" do
      file = Tempfile.new(["file", ".jpeg"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("image/jpeg")
    end

    it "handles .gif file extensions" do
      file = Tempfile.new(["file", ".gif"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("image/gif")
    end

    it "handles .png file extensions" do
      file = Tempfile.new(["file", ".png"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("image/png")
    end

    it "handles .pdf file extensions" do
      file = Tempfile.new(["file", ".pdf"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/pdf")
    end

    it "handles .csv file extensions" do
      file = Tempfile.new(["file", ".csv"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("text/csv")
    end

    it "handles .rtf file extensions" do
      file = Tempfile.new(["file", ".rtf"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("text/rtf")
    end

    it "handles .doc file extensions" do
      file = Tempfile.new(["file", ".doc"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/msword")
    end

    it "handles .docx file extensions" do
      file = Tempfile.new(["file", ".docx"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/vnd.openxmlformats-officedocument.wordprocessingml.document")
    end

    it "handles .xls file extensions" do
      file = Tempfile.new(["file", ".xls"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/vnd.ms-excel")
    end

    it "handles .xlsx file extensions" do
      file = Tempfile.new(["file", ".xlsx"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
    end

    it "handles .odt file extensions" do
      file = Tempfile.new(["file", ".odt"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/vnd.oasis.opendocument.text")
    end

    it "handles .ods file extensions" do
      file = Tempfile.new(["file", ".ods"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/vnd.oasis.opendocument.spreadsheet")
    end

    it "handles .svg file extensions" do
      file = Tempfile.new(["file", ".svg"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("image/svg+xml")
    end

    it "handles .dot file extensions" do
      file = Tempfile.new(["file", ".dot"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/msword")
    end

    it "handles .ppt file extensions" do
      file = Tempfile.new(["file", ".ppt"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/vnd.ms-powerpoint")
    end

    it "handles .pptx file extensions" do
      file = Tempfile.new(["file", ".pptx"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/vnd.openxmlformats-officedocument.presentationml.presentation")
    end

    it "handles .rdf file extensions" do
      file = Tempfile.new(["file", ".rdf"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/rdf+xml")
    end

    it "handles .xlsm file extensions" do
      file = Tempfile.new(["file", ".xlsm"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/vnd.ms-excel.sheet.macroEnabled.12")
    end

    it "handles .xlt file extensions" do
      file = Tempfile.new(["file", ".xlt"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/vnd.ms-excel")
    end

    it "handles .txt file extensions and adds the charset parameter" do
      file = Tempfile.new(["file", ".txt"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("text/plain; charset=utf-8")
    end

    it "handles .gml file extensions" do
      file = Tempfile.new(["file", ".gml"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/gml+xml")
    end

    it "handles .dxf file extensions" do
      file = Tempfile.new(["file", ".dxf"])
      asset = described_class.new(file:)
      expect(asset.content_type_from_extension).to eq("application/dxf")
    end
  end

  describe "#image?" do
    let(:asset) { described_class.new }

    before do
      allow(asset).to receive(:extension).and_return(extension)
    end

    context "when asset is an image" do
      let(:extension) { "png" }

      it "returns a truth-y value" do
        expect(asset).to be_image
      end
    end

    context "when asset is not an image" do
      let(:extension) { "pdf" }

      it "returns a false-y value" do
        expect(asset).not_to be_image
      end
    end
  end

  describe "#etag_from_file" do
    let(:asset) { described_class.new }

    let(:size) { 1024 }
    let(:mtime) { Time.zone.parse("2017-01-01") }
    let(:stat) { instance_double(File::Stat, size:, mtime:) }

    before do
      asset.file = load_fixture_file("asset.png")
      allow(File).to receive(:stat).and_return(stat)
    end

    it "returns string made up of 2 parts separated by a hyphen" do
      parts = asset.etag_from_file.split("-")
      expect(parts.length).to eq(2)
    end

    it "has 1st part as file mtime (unix time in seconds written in lowercase hex)" do
      last_modified_hex = asset.etag_from_file.split("-").first
      last_modified = last_modified_hex.to_i(16)
      expect(last_modified).to eq(mtime.to_i)
    end

    it "has 2nd part as file size (number of bytes written in lowercase hex)" do
      size_hex = asset.etag_from_file.split("-").last
      asset_size = size_hex.to_i(16)
      expect(asset_size).to eq(size)
    end
  end

  describe "#etag" do
    let(:asset) { described_class.new(file: load_fixture_file("asset.png"), etag:) }

    before do
      allow(asset).to receive(:etag_from_file).and_return("etag-from-file")
    end

    context "when asset is created" do
      let(:etag) { nil }

      before do
        asset.save!
      end

      it "stores the value generated from the file in the database" do
        expect(asset.reload.etag).to eq("etag-from-file")
      end

      context "when asset is updated with new file" do
        let(:new_file) { load_fixture_file("asset2.jpg") }

        before do
          allow(asset).to receive(:etag_from_file).and_return("etag-from-new-file")
          asset.update!(file: new_file)
        end

        it "stores the value generated from the new file in the database" do
          expect(asset.reload.etag).to eq("etag-from-new-file")
        end
      end
    end
  end

  describe "#etag=" do
    let(:asset) { described_class.new }

    it "cannot be called from outside the Asset class" do
      expect { asset.etag = "etag-value" }.to raise_error(NoMethodError)
    end
  end

  describe "#last_modified_from_file" do
    let(:asset) { described_class.new }

    let(:mtime) { Time.zone.parse("2017-01-01") }
    let(:stat) { instance_double(File::Stat, mtime:) }

    before do
      asset.file = load_fixture_file("asset.png")
      allow(File).to receive(:stat).and_return(stat)
    end

    it "returns time file was last modified" do
      expect(asset.last_modified_from_file).to eq(mtime)
    end
  end

  describe "#last_modified" do
    let(:asset) { described_class.new(file: load_fixture_file("asset.png"), last_modified:) }

    let(:time) { Time.zone.parse("2002-02-02 02:02") }
    let(:time_from_file) { Time.zone.parse("2001-01-01 01:01") }

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
        let(:time_from_new_file) { Time.zone.parse("2003-03-03 03:03") }

        before do
          allow(asset).to receive(:last_modified_from_file).and_return(time_from_new_file)
          asset.update!(file: new_file)
        end

        it "stores the value generated from the new file in the database" do
          expect(asset.reload.last_modified).to eq(time_from_new_file)
        end
      end
    end
  end

  describe "#last_modified=" do
    let(:asset) { described_class.new }

    it "cannot be called from outside the Asset class" do
      expect { asset.last_modified = Time.zone.now }.to raise_error(NoMethodError)
    end
  end

  describe "#size_from_file" do
    let(:asset) { described_class.new(file: load_fixture_file("asset.png")) }
    let(:size) { 57_705 }

    it "returns the size of the file" do
      expect(asset.size_from_file).to eq(size)
    end
  end

  describe "#size" do
    let(:asset) { described_class.new(file: load_fixture_file("asset.png"), size:) }
    let(:asset_size) { 100 }

    before do
      allow(asset).to receive(:size).and_return(asset_size)
    end

    context "when asset is created" do
      let(:size) { nil }

      before do
        asset.save!
      end

      it "stores the value generated from the file in the database" do
        expect(asset.reload.size).to eq(asset_size)
      end

      context "when asset is updated with new file" do
        let(:new_file) { load_fixture_file("asset2.jpg") }
        let(:new_asset_size) { 200 }

        before do
          allow(asset).to receive(:size).and_return(new_asset_size)
          asset.update!(file: new_file)
        end

        it "stores the value generated from the new file in the database" do
          expect(asset.reload.size).to eq(new_asset_size)
        end
      end
    end
  end

  describe "#size=" do
    let(:asset) { described_class.new }

    it "cannot be called from outside the Asset class" do
      expect { asset.size = 100 }.to raise_error(NoMethodError)
    end
  end

  describe "#md5_hexdigest_from_file" do
    let(:asset) { described_class.new(file: load_fixture_file("asset.png")) }
    let(:md5_hexdigest) { "a0d8aa55f6db670e38a14962c0652776" }

    it "returns MD5 hex digest for asset file content" do
      expect(asset.md5_hexdigest_from_file).to eq(md5_hexdigest)
    end
  end

  describe "#md5_hexdigest" do
    let(:asset) { described_class.new(file: load_fixture_file("asset.png"), md5_hexdigest:) }

    before do
      allow(asset).to receive(:md5_hexdigest_from_file).and_return("md5-from-file")
    end

    context "when asset is created" do
      let(:md5_hexdigest) { nil }

      before do
        asset.save!
      end

      it "stores the value generated from the file in the database" do
        expect(asset.reload.md5_hexdigest).to eq("md5-from-file")
      end

      context "when asset is updated with new file" do
        let(:new_file) { load_fixture_file("asset2.jpg") }

        before do
          allow(asset).to receive(:md5_hexdigest_from_file).and_return("md5-from-new-file")
          asset.update!(file: new_file)
        end

        it "stores the value generated from the new file in the database" do
          expect(asset.reload.md5_hexdigest).to eq("md5-from-new-file")
        end
      end
    end
  end

  describe "#md5_hexdigest=" do
    let(:asset) { described_class.new }

    it "cannot be called from outside the Asset class" do
      expect { asset.md5_hexdigest = "md5-value" }.to raise_error(NoMethodError)
    end
  end

  describe "#upload_success!" do
    context "when asset is unscanned" do
      let(:asset) { FactoryBot.create(:asset) }

      it "does not allow asset state change to uploaded" do
        expect { asset.upload_success! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end

    context "when asset is clean" do
      let(:asset) { FactoryBot.create(:clean_asset) }
      let(:path) { asset.file.path }

      it "changes asset state to uploaded" do
        asset.upload_success!

        expect(asset.reload).to be_uploaded
      end

      it "triggers the delete asset file worker" do
        expect(DeleteAssetFileFromNfsWorker).to receive(:perform_in)
        asset.upload_success!
      end
    end

    context "when asset is infected" do
      let(:asset) { FactoryBot.create(:infected_asset) }

      it "does not allow asset state change to uploaded" do
        expect { asset.upload_success! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end

    context "when asset is uploaded" do
      let(:asset) { FactoryBot.create(:uploaded_asset) }

      it "does not allow asset state change to uploaded" do
        expect { asset.upload_success! }
          .to raise_error(StateMachines::InvalidTransition)
      end
    end
  end

  describe "#save" do
    let(:asset) { FactoryBot.create(:clean_asset) }

    context "when asset has been uploaded to cloud storage" do
      before do
        asset.upload_success!
      end

      it "saves asset successfully despite having no file" do
        expect(asset.save).to be_truthy
      end
    end

    context "when the file name is unchanged" do
      let(:saved_asset) { FactoryBot.create(:asset) }
      let(:md5_hexdigest) { saved_asset.md5_hexdigest }
      let(:original_filename) { saved_asset.file.send(:original_filename) }

      it "updates the md5 hexdigest" do
        asset = described_class.find(saved_asset.id) # find to clear memoization
        asset.update!(file: load_fixture_file("lorem.txt", named: original_filename))

        expect(asset.md5_hexdigest).not_to eq md5_hexdigest
      end
    end
  end

  describe "#replacement" do
    let(:asset) { FactoryBot.build(:asset, replacement:) }

    context "when replacement is nil" do
      let(:replacement) { nil }

      it "is valid" do
        expect(asset).to be_valid
      end

      it "has no replacement_id" do
        expect(asset.replacement_id).to be_nil
      end
    end

    context "when replacement is set" do
      let(:replacement) { FactoryBot.create(:asset) }

      it "is valid" do
        expect(asset).to be_valid
      end

      it "persists replacement when saved" do
        asset.save!

        expect(asset.reload.replacement).to eq(replacement)
      end

      it "persists replacement_id when saved" do
        asset.save!

        expect(asset.reload.replacement_id).to eq(replacement.id)
      end
    end
  end

  describe "#parent_document_url" do
    let(:asset) { described_class.new }

    it "is nil by default" do
      expect(asset.parent_document_url).to be_nil
    end

    it "can be set" do
      asset.parent_document_url = "parent-document-url"
      expect(asset.parent_document_url).to eql("parent-document-url")
    end
  end

  describe "#access_limited?" do
    let(:asset) { described_class.new }

    it "is true if the access is limited to a user" do
      asset.access_limited = %w[user-id]
      expect(asset.access_limited?).to be true
    end

    it "is true if the access is limited to an organisation" do
      asset.access_limited_organisation_ids = %w[organisation-id]
      expect(asset.access_limited?).to be true
    end

    it "is false if the access is not limited to neither users nor organisations" do
      expect(asset.access_limited?).to be false
    end
  end
end
