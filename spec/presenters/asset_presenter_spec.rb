require "rails_helper"

RSpec.describe AssetPresenter do
  subject(:presenter) { described_class.new(asset, view_context) }

  let(:asset) { FactoryBot.build(:asset) }
  let(:view_context) { instance_double(ActionView::Base) }

  describe "#as_json" do
    let(:options) { {} }
    let(:json) { presenter.as_json(options) }
    let(:asset_url) { "asset-url" }
    let(:public_url_path) { "/public-url-path" }

    before do
      allow(view_context).to receive(:asset_url).with(asset.id).and_return(asset_url)
      allow(asset).to receive(:public_url_path).and_return(public_url_path)
    end

    context "when no status is supplied" do
      let(:options) { { status: nil } }

      it "returns hash including default response status" do
        expect(json).to include(_response_info: { status: "ok" })
      end
    end

    context "when status is supplied" do
      let(:options) { { status: "not_found" } }

      it "returns hash including response status" do
        expect(json).to include(_response_info: { status: "not_found" })
      end
    end

    it "returns hash including asset URL as API identifier" do
      expect(json).to include(id: "asset-url")
    end

    it "returns hash including asset filename as name" do
      expect(json).to include(name: "asset.png")
    end

    it "returns hash including asset content type" do
      expect(json).to include(content_type: "image/png")
    end

    it "returns hash with a size key" do
      expect(json).to have_key(:size)
    end

    it "return hash including deleted state" do
      expect(json).to include(deleted: false)
    end

    context "when the asset has been saved" do
      before do
        asset.save
      end

      it "returns hash including asset size" do
        expect(json).to include(size: 57_705)
      end
    end

    context "when the asset has been saved and then destroyed" do
      before do
        asset.save!
        asset.destroy
      end

      it "return hash including deleted state" do
        expect(json).to include(deleted: true)
      end
    end

    it "returns hash including public asset URL as file_url" do
      uri = URI.parse(json[:file_url])
      expect("#{uri.scheme}://#{uri.host}").to eq(Plek.new.asset_root)
      expect(uri.path).to eq(public_url_path)
    end

    it "returns hash including asset state" do
      expect(json).to include(state: "unscanned")
    end

    it "returns hash including asset draft status as false" do
      expect(json).to include(draft: false)
    end

    context "when asset is draft" do
      before do
        asset.draft = true
      end

      it "returns hash including asset draft status as true" do
        expect(json).to include(draft: true)
      end
    end

    context "when public url path contains non-ascii characters" do
      let(:public_url_path) { "/public-ürl-path" }

      it "URI encodes the public asset URL" do
        uri = URI.parse(json[:file_url])
        expect(uri.path).to eq("/public-%C3%BCrl-path")
      end
    end

    context "when asset has no parent document URL" do
      before do
        asset.parent_document_url = nil
      end

      it "returns hash without parent_document_url" do
        expect(json).not_to have_key(:parent_document_url)
      end
    end

    context "when asset has parent document URL" do
      let(:parent_document_url) { "https://example.com/path/file.ext" }

      before do
        asset.parent_document_url = parent_document_url
      end

      it "returns hash including parent_document_url" do
        expect(json).to include(parent_document_url: parent_document_url)
      end
    end

    context "when asset has no redirect URL" do
      before do
        asset.redirect_url = nil
      end

      it "returns hash without redirect_url" do
        expect(json).not_to have_key(:redirect_url)
      end
    end

    context "when asset has redirect URL" do
      let(:redirect_url) { "https://example.com/path/file.ext" }

      before do
        asset.redirect_url = redirect_url
      end

      it "returns hash including redirect_url" do
        expect(json).to have_key(:redirect_url)
      end
    end

    context "when asset has no replacement" do
      before do
        asset.replacement = nil
      end

      it "returns hash without replacement_id" do
        expect(json).not_to have_key(:replacement_id)
      end
    end

    context "when asset has replacement" do
      let(:replacement) { FactoryBot.create(:asset) }
      let(:replacement_id) { replacement.id.to_s }

      before do
        asset.replacement = replacement
      end

      it "returns hash including replacement_id" do
        expect(json).to include(replacement_id: replacement_id)
      end
    end
  end
end
