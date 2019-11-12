require "rails_helper"

RSpec.describe WhitehallAssetClonerController, type: :controller do
  render_views # for json responses

  before do
    login_as_stub_user
  end

  describe "POST whitehall_assets_to_asset" do
    context "a valid WhitehallAsset that is not already being redirected" do
      subject!(:response) do
        post :clone_whitehall_asset_to_asset, params: {
          legacy_url_path: whitehall_asset_path,
        }
      end

      before do
        FactoryBot.create(
          :whitehall_asset,
          draft: true,
          state: "uploaded",
          redirect_url: "/foo",
          parent_document_url: "https://www.gov.uk/parent",
          created_at: 2.days.ago,
          updated_at: 1.day.ago,
          access_limited: %w[abc123],
          access_limited_organisation_ids: %w[def456],
          auth_bypass_ids: %w[ghi789],
          legacy_url_path: whitehall_asset_path,
        )
      end

      let(:whitehall_asset_path) { "/government/uploads/asset.png" }
      let(:whitehall_asset) { WhitehallAsset.last }
      let(:asset) { Asset.last }

      it "creates an Asset referencing the same file" do
        expect(asset.size).to eq(whitehall_asset.size)
        expect(asset.file_url.split("/").last).to eq(whitehall_asset.file_url.split("/").last)
        expect(asset.md5_hexdigest).to eq(whitehall_asset.md5_hexdigest)
      end

      it "copies timestamp data from WhitehallAsset to Asset" do
        expect(asset.created_at).to eq(whitehall_asset.created_at)
        expect(asset.updated_at).to eq(whitehall_asset.updated_at)
      end

      it "copies auth and access data from WhitehallAsset to Asset" do
        expect(asset.created_at).to eq(whitehall_asset.created_at)
        expect(asset.updated_at).to eq(whitehall_asset.updated_at)
        expect(asset.access_limited).to eq(whitehall_asset.access_limited)
        expect(asset.access_limited_organisation_ids).to eq(whitehall_asset.access_limited_organisation_ids)
        expect(asset.auth_bypass_ids).to eq(whitehall_asset.auth_bypass_ids)
      end

      it "returns Asset filename, URL and other info in the JSON response" do
        body = JSON.parse(response.body)

        expect(response.status).to eq(201)
        expect(body["name"]).to eq("asset.png")
        expect(body["file_url"]).to match(%r{\Ahttp://static.dev.gov.uk/media/[a-z0-9]+/asset.png\z})
        expect(body["state"]).to eq("uploaded")
      end
    end
  end
end
