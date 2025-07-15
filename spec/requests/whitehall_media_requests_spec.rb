require "rails_helper"

RSpec.describe "Whitehall media requests", type: :request do
  shared_examples "redirects to placeholders" do
    let(:asset) do
      FactoryBot.create(
        :whitehall_asset,
        file: load_fixture_file(File.basename(path)),
        legacy_url_path: path,
        state:,
      )
    end
    let(:s3) { S3Configuration.build }

    before do
      allow(cloud_storage).to receive(:presigned_url_for)
                                .with(asset, http_method:).and_return(presigned_url)
      allow(AssetManager).to receive(:s3).and_return(s3)
      allow(s3).to receive(:fake?).and_return(false)
      get path
    end

    context "when asset is an image" do
      let(:path) { "/government/uploads/asset.png" }

      it "redirects to placeholder image" do
        expect(response).to redirect_to(%r{/asset-manager/thumbnail-placeholder-.*\.png})
      end

      it "sets the Cache-Control response header to 1 minute" do
        expect(response.headers["Cache-Control"]).to eq("max-age=60, public")
      end
    end

    context "when asset is not an image" do
      let(:path) { "/government/uploads/lorem.txt" }

      it "redirects to government placeholder page" do
        expect(response).to redirect_to("/government/placeholder")
      end

      it "sets the Cache-Control response header to 1 minute" do
        expect(response.headers["Cache-Control"]).to eq("max-age=60, public")
      end
    end
  end

  let(:cloud_storage) { instance_double(S3Storage) }
  let(:http_method) { "GET" }
  let(:presigned_url) { "https://s3-host.test/presigned-url" }

  before do
    stub_user
    allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
  end

  describe "request for an asset which does not exist" do
    it "responds with 404 Not Found status" do
      get "/government/uploads/asset.png"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "request for an unscanned asset" do
    let(:state) { "unscanned" }

    include_examples "redirects to placeholders"
  end

  describe "request for an clean asset" do
    let(:state) { "clean" }

    include_examples "redirects to placeholders"
  end

  describe "request for an uploaded asset" do
    let(:path) { "/government/uploads/asset.png" }
    let(:asset) { FactoryBot.create(:uploaded_whitehall_asset, legacy_url_path: path) }
    let(:s3) { S3Configuration.build }

    before do
      allow(cloud_storage).to receive(:presigned_url_for)
                                .with(asset, http_method:).and_return(presigned_url)
      allow(AssetManager).to receive(:s3).and_return(s3)
      allow(s3).to receive(:fake?).and_return(false)
      get path,
          headers: {
            "HTTP_X_SENDFILE_TYPE" => "X-Accel-Redirect",
            "HTTP_X_ACCEL_MAPPING" => Rails.root.join("tmp/test_uploads/assets/=/raw/"),
          }
    end

    it "responds with 200 OK" do
      expect(response).to have_http_status(:ok)
    end

    it "sets the X-Accel-Redirect response header" do
      expected_path = "/cloud-storage-proxy/#{presigned_url}"
      expect(response.headers["X-Accel-Redirect"]).to eq(expected_path)
    end

    it "sets the Content-Type response header" do
      expect(response.headers["Content-Type"]).to eq("image/png")
    end

    it "sets the Content-Disposition response header" do
      expect(response.headers["Content-Disposition"]).to eq('inline; filename="asset.png"')
    end

    it "sets the Cache-Control response header to 30 minutes" do
      expect(response.headers["Cache-Control"]).to eq("max-age=1800, public")
    end

    it "sets the X-Frame-Options response header to DENY" do
      expect(response.headers["X-Frame-Options"]).to eq("DENY")
    end
  end

  describe "request for a previously uploaded asset which no longer exists" do
    let(:path) { "/government/uploads/asset.png" }
    let(:asset) { FactoryBot.create(:uploaded_whitehall_asset, legacy_url_path: path) }

    it "responds with 410 Gone status" do
      asset.update!(deleted_at: Time.zone.now)

      get path

      expect(response).to have_http_status(:gone)
    end
  end

  describe "requesting a draft asset while logged in" do
    around do |example|
      ClimateControl.modify(GDS_SSO_MOCK_INVALID: "1") { example.run }
    end

    before do
      GDS::SSO.test_user = User.first
      host! AssetManager.govuk.draft_assets_host
      allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
      allow(cloud_storage).to receive(:presigned_url_for)
                                .with(asset, http_method:).and_return("https://s3-host.test/presigned-url")
    end

    let(:path) { "/government/uploads/asset.png" }
    let(:auth_bypass_id) { "bypass-id" }

    let(:valid_token) { JWT.encode({ "sub" => auth_bypass_id }, Rails.application.config_for(:secrets).jwt_auth_secret, "HS256") }
    let(:token_without_access) { JWT.encode({ "sub" => "not-the-right-bypass-id" }, Rails.application.config_for(:secrets).jwt_auth_secret, "HS256") }

    context "when the asset is not access limited" do
      let(:asset) do
        FactoryBot.create(
          :uploaded_whitehall_asset,
          file: load_fixture_file(File.basename(path)),
          draft: true,
          auth_bypass_ids: [auth_bypass_id],
          legacy_url_path: path,
        )
      end
      let(:s3) { S3Configuration.build }

      before do
        allow(AssetManager).to receive(:s3).and_return(s3)
        allow(s3).to receive(:fake?).and_return(false)
      end

      it "serves the asset without a valid token" do
        get path
        expect(response).to be_successful
      end

      it "serves the asset with a valid token" do
        get "#{path}?token=#{valid_token}"
        expect(response).to be_successful
      end
    end

    context "when the asset is access limited, and the user has access" do
      let(:asset) do
        FactoryBot.create(
          :uploaded_whitehall_asset,
          file: load_fixture_file(File.basename(path)),
          draft: true,
          auth_bypass_ids: [auth_bypass_id],
          access_limited: [User.first.uid],
        )
      end

      it "serves the asset without a valid token" do
        get path
        expect(response).to be_successful
      end

      it "serves the asset with a valid token" do
        get "#{path}?token=#{valid_token}"
        expect(response).to be_successful
      end
    end

    context "when the asset is access limited to a different user" do
      let(:asset) do
        FactoryBot.create(
          :uploaded_whitehall_asset,
          file: load_fixture_file(File.basename(path)),
          legacy_url_path: path,
          draft: true,
          auth_bypass_ids: [auth_bypass_id],
          access_limited: %w[some-other-user],
        )
      end
      let(:s3) { S3Configuration.build }

      before do
        allow(AssetManager).to receive(:s3).and_return(s3)
        allow(s3).to receive(:fake?).and_return(false)
      end

      it "does not serve the asset without a valid token" do
        get path
        expect(response).to be_forbidden
      end

      it "serves the asset with a valid token" do
        get "#{path}?token=#{valid_token}"
        expect(response).to be_successful
      end

      it "does not serve the asset with a token containing the wrong auth bypass id" do
        get "#{path}?token=#{token_without_access}"
        expect(response).to be_forbidden
      end
    end
  end
end
