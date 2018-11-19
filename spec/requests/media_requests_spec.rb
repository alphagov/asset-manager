require "rails_helper"

RSpec.describe "Media requests", type: :request do
  describe "requesting an asset that doesn't exist" do
    it "responds with not found status" do
      get "/media/34/test.jpg"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "request an asset that does exist" do
    let(:cloud_storage) { instance_double(S3Storage) }
    let(:http_method) { 'GET' }
    let(:presigned_url) { 'https://s3-host.test/presigned-url' }

    let(:asset) { FactoryBot.create(:uploaded_asset) }

    before do
      allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
      allow(cloud_storage).to receive(:presigned_url_for)
        .with(asset, http_method: http_method).and_return(presigned_url)

      get "/media/#{asset.id}/asset.png", headers: {
        "HTTP_X_SENDFILE_TYPE" => "X-Accel-Redirect",
        "HTTP_X_ACCEL_MAPPING" => "#{Rails.root}/tmp/test_uploads/assets/=/raw/"
      }
    end

    it "sets the X-Accel-Redirect header" do
      expect(response).to be_successful
      expect(response.headers["X-Accel-Redirect"]).to eq("/cloud-storage-proxy/#{presigned_url}")
    end

    it "sets the correct content headers" do
      expect(response.headers["Content-Type"]).to eq("image/png")
      expect(response.headers["Content-Disposition"]).to eq('inline; filename="asset.png"')
    end

    it "sets the X-Frame-Options header to DENY" do
      expect(response.headers["X-Frame-Options"]).to eq('DENY')
    end
  end
end
