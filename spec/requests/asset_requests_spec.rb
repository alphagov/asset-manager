require "rails_helper"

RSpec.describe "Asset requests", type: :request do
  before do
    login_as_stub_user
  end

  around do |example|
    ClimateControl.modify(GOVUK_ASSET_ROOT: "http://assets.digital.cabinet-office.gov.uk") { example.run }
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
    let(:asset_id) do
      post "/assets", params: { asset: { file: load_fixture_file("asset.png") } }
      body = JSON.parse(response.body)
      body.fetch("id").split("/").last
    end

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
      expect(body["deleted"]).to be(true)
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

  describe "creating then redirecting an asset" do
    it "does not result in an invalid transition error when a redirect is received in short succession after a create" do
      # use threads to simulate multiple sidekiq workers
      threads = []
      allow(VirusScanWorker).to receive(:perform_async) do |asset_id|
        threads << Thread.new do
          sleep(0.5)
          asset = Asset.find(asset_id)
          asset.scanned_clean!
        end
      end

      post "/assets", params: { asset: { file: load_fixture_file("lorem.txt") } }
      asset_id = Asset.last.id
      put "/assets/#{asset_id}", params: { asset: { file: load_fixture_file("lorem.txt"), redirect_url: "/some-redirect" } }

      # run the thread(s) concurrently - instead of doing Worker.drain to ensure they're processed concurrently
      threads.each(&:join)

      asset = Asset.find(asset_id)

      expect(asset.state).to eq("clean")
      expect(asset.redirect_url).to eq("/some-redirect")
    end
  end
end
