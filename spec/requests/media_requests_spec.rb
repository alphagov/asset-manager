require "rails_helper"

RSpec.describe "Media requests", type: :request do
  before do
    not_logged_in
    # create a user that can be used automatically with GDS SSO mock
    stub_user
  end

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

  describe "requesting a draft asset from live" do
    around do |example|
      ClimateControl.modify(GDS_SSO_MOCK_INVALID: "1") { example.run }
    end

    let(:asset) do
      FactoryBot.create(:uploaded_asset, draft: true)
    end

    it "redirects to the draft host" do
      get download_media_path(id: asset, filename: "asset.png")

      expect(response).to redirect_to(download_media_url(host: AssetManager.govuk.draft_assets_host,
                                                         id: asset,
                                                         filename: "asset.png"))
    end

    it "preserves any query params" do
      get download_media_path(id: asset, filename: "asset.png", params: { foo: "bar" })

      expect(response).to redirect_to(download_media_url(host: AssetManager.govuk.draft_assets_host,
                                                         id: asset,
                                                         filename: "asset.png",
                                                         params: { foo: "bar" }))
    end
  end

  describe "requesting a draft asset while not logged in" do
    around do |example|
      ClimateControl.modify(GDS_SSO_MOCK_INVALID: "1") { example.run }
    end

    before { host! AssetManager.govuk.draft_assets_host }

    let(:auth_bypass_id) { "bypass-id" }
    let(:asset) do
      FactoryBot.create(:uploaded_asset, draft: true, auth_bypass_ids: [auth_bypass_id])
    end

    it "redirects to login without a valid token" do
      get "/media/#{asset.id}/asset.png"
      expect(response).to redirect_to("/auth/gds")
    end

    it "serves the asset with a valid token" do
      secret = Rails.application.secrets.jwt_auth_secret
      valid_token = JWT.encode({ "sub" => auth_bypass_id }, secret, "HS256")
      get "/media/#{asset.id}/asset.png", params: { token: valid_token }
      expect(response).to be_successful
    end
  end
end
