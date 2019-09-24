require "rails_helper"

RSpec.describe "Asset requests", type: :request do
  before do
    login_as_stub_user
    allow_any_instance_of(Plek).to receive(:asset_root).and_return("http://assets.digital.cabinet-office.gov.uk")
  end

  describe "uploading an asset" do
    it "creates an asset with the file provided" do
      post "/assets", params: { asset: { file: load_fixture_file("asset.png") } }
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:created)
      expect(body["_response_info"]["status"]).to eq("created")

      expect(body["id"]).to match(%r{http://www.example.com/assets/[a-z0-9]+})
      expect(body["name"]).to eq("asset.png")
      expect(body["content_type"]).to eq("image/png")
      expect(body["state"]).to eq("unscanned")
    end

    it "cannot create an asset without a file" do
      post "/assets", params: { asset: { file: nil } }
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body["_response_info"]["status"]).to eq(["File can't be blank"])
    end
  end

  describe "updating an asset" do
    let(:asset_id) {
      post "/assets", params: { asset: { file: load_fixture_file("asset.png") } }
      body = JSON.parse(response.body)
      body.fetch("id").split("/").last
    }

    it "updates an asset with the file provided" do
      put "/assets/#{asset_id}", params: { asset: { file: load_fixture_file("asset2.jpg") } }
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(body["_response_info"]["status"]).to eq("success")

      expect(body["id"]).to end_with(asset_id)
      expect(body["name"]).to eq("asset2.jpg")
      expect(body["content_type"]).to eq("image/jpeg")
      expect(body["state"]).to eq("unscanned")
    end

    it "cannot create an asset without a file" do
      post "/assets", params: { asset: { file: nil } }
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(body["_response_info"]["status"]).to eq(["File can't be blank"])
    end
  end

  describe "retrieving an asset" do
    it "retreives details about an existing asset" do
      asset = FactoryBot.create(:uploaded_asset)

      get "/assets/#{asset.id}"
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(body["_response_info"]["status"]).to eq("ok")

      expect(body["id"]).to eq("http://www.example.com/assets/#{asset.id}")
      expect(body["name"]).to eq("asset.png")
      expect(body["content_type"]).to eq("image/png")
      expect(body["file_url"]).to eq("http://assets.digital.cabinet-office.gov.uk/media/#{asset.id}/asset.png")
      expect(body["state"]).to eq("uploaded")
    end

    it "returns details about an infected asset" do
      asset = FactoryBot.create(:infected_asset)

      get "/assets/#{asset.id}"
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(body["_response_info"]["status"]).to eq("ok")

      expect(body["id"]).to eq("http://www.example.com/assets/#{asset.id}")
      expect(body["name"]).to eq("asset.png")
      expect(body["content_type"]).to eq("image/png")
      expect(body["file_url"]).to eq("http://assets.digital.cabinet-office.gov.uk/media/#{asset.id}/asset.png")
      expect(body["state"]).to eq("infected")
    end

    it "cannot retrieve details about an asset which does not exist" do
      get "/assets/blah"
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:not_found)
      expect(body["_response_info"]["status"]).to eq("not found")
    end
  end

  describe "deleting an asset" do
    it "soft deletes an existing asset" do
      asset = FactoryBot.create(:uploaded_asset)

      delete "/assets/#{asset.id}"
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(body["_response_info"]["status"]).to eq("success")
      expect(body["id"]).to eq("http://www.example.com/assets/#{asset.id}")
      expect(body["name"]).to eq("asset.png")
      expect(body["content_type"]).to eq("image/png")
      expect(body["file_url"]).to eq("http://assets.digital.cabinet-office.gov.uk/media/#{asset.id}/asset.png")
      expect(body["state"]).to eq("uploaded")

      get "/assets/#{asset.id}"
      body = JSON.parse(response.body)

      expect(response).to have_http_status(:ok)
      expect(body["deleted"]).to eq(true)
    end
  end

  describe "restoring an asset" do
    it "restores a soft deleted asset" do
      asset = FactoryBot.create(:uploaded_asset)

      post "/assets/#{asset.id}/restore"

      body = JSON.parse(response.body)

      expect(response).to have_http_status(:success)
      expect(body["_response_info"]["status"]).to eq("success")
      expect(body["id"]).to eq("http://www.example.com/assets/#{asset.id}")
      expect(body["name"]).to eq("asset.png")
      expect(body["content_type"]).to eq("image/png")
      expect(body["file_url"]).to eq("http://assets.digital.cabinet-office.gov.uk/media/#{asset.id}/asset.png")
      expect(body["state"]).to eq("uploaded")

      get "/assets/#{asset.id}"

      expect(response).to be_successful
    end
  end
end
