require "rails_helper"

RSpec.describe "Virus scanning of uploaded images", type: :request, disable_cloud_storage_stub: true do
  before do
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

    VirusScanWorker.drain

    get download_media_path(id: asset, filename: "lorem.txt")
    expect(response).to have_http_status(:not_found)

    SaveToCloudStorageWorker.drain

    get download_media_path(id: asset, filename: "lorem.txt")
    expect(response).to have_http_status(:success)

    redirect_url = headers["X-Accel-Redirect"]
    cloud_url = redirect_url.match(%r{^/cloud-storage-proxy/(.*)$})[1]
    get cloud_url
    expect(response).to have_http_status(:success)
  end
end
