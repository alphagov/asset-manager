require "rails_helper"

RSpec.describe "Virus scanning of uploaded images", :disable_cloud_storage_stub, type: :request do
  let(:s3) { S3Configuration.build }

  before do
    allow(AssetManager).to receive(:s3).and_return(s3)
    allow(s3).to receive(:fake?).and_return(true)
    login_as_stub_user
  end

  specify "a clean asset is available after virus scanning & uploading to cloud storage" do
    post "/assets", params: { asset: { file: load_fixture_file("lorem.txt") } }
    expect(response).to have_http_status(:created)

    asset = Asset.last

    asset_details = JSON.parse(response.body)
    expect(asset_details["id"]).to match(%r{http://www.example.com/assets/#{asset.id}})

    get download_media_path(id: asset, filename: "lorem.txt")
    expect(response).to have_http_status(:not_found)

    allow(Services.virus_scanner).to receive(:scan)
    VirusScanWorker.drain

    get download_media_path(id: asset, filename: "lorem.txt")
    expect(response).to have_http_status(:not_found)

    SaveToCloudStorageWorker.drain

    get download_media_path(id: asset, filename: "lorem.txt")
    expect(response).to have_http_status(:found)

    redirect_url = headers["location"]
    get redirect_url
    expect(response).to have_http_status(:success)
  end
end
