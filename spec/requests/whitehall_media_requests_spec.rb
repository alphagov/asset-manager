require "rails_helper"

RSpec.describe "Whitehall media requests", type: :request do
  shared_examples "redirects to placeholders" do
    let(:asset) {
      FactoryBot.create(
        :whitehall_asset,
        file: load_fixture_file(File.basename(path)),
        legacy_url_path: path,
        state: state,
      )
    }

    before do
      allow(cloud_storage).to receive(:presigned_url_for)
        .with(asset, http_method: http_method).and_return(presigned_url)

      get path
    end

    context "when asset is an image" do
      let(:path) { "/government/uploads/asset.png" }

      it "redirects to placeholder image" do
        expect(response).to redirect_to(%r(/asset-manager/thumbnail-placeholder-.*\.png))
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

    before do
      allow(cloud_storage).to receive(:presigned_url_for)
        .with(asset, http_method: http_method).and_return(presigned_url)

      get path, headers: {
        "HTTP_X_SENDFILE_TYPE" => "X-Accel-Redirect",
        "HTTP_X_ACCEL_MAPPING" => "#{Rails.root}/tmp/test_uploads/assets/=/raw/",
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

    it "sets the Cache-Control response header to 24 hours" do
      expect(response.headers["Cache-Control"]).to eq("max-age=86400, public")
    end

    it "sets the X-Frame-Options response header to DENY" do
      expect(response.headers["X-Frame-Options"]).to eq("DENY")
    end
  end
end
