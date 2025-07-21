require "rails_helper"

RSpec.describe WhitehallMediaController, type: :controller do
  shared_examples "redirects to placeholders" do
    before do
      allow(asset).to receive(:image?).and_return(image)
    end

    context "and asset is image" do
      let(:image) { true }

      it "redirects to thumbnail-placeholder image" do
        get :download, params: { path:, format: }

        expect(controller).to redirect_to(described_class.helpers.image_path("thumbnail-placeholder.png"))
      end
    end

    context "and asset is not an image" do
      let(:image) { false }

      it "redirects to government placeholder page" do
        get :download, params: { path:, format: }

        expect(controller).to redirect_to("/government/placeholder")
      end
    end
  end

  describe "#download" do
    let(:path) { "path/to/asset" }
    let(:format) { "png" }
    let(:legacy_url_path) { "/government/uploads/#{path}.#{format}" }
    let(:draft) { false }
    let(:redirect_url) { nil }
    let(:attributes) do
      {
        legacy_url_path:,
        state:,
        draft:,
        redirect_url:,
      }
    end
    let(:asset) { FactoryBot.build(:whitehall_asset, attributes) }

    before do
      not_logged_in
      allow(WhitehallAsset).to receive(:find_by).with(legacy_url_path:).and_return(asset)
    end

    context "when asset is uploaded" do
      let(:state) { "uploaded" }

      it "proxies asset to S3 via Nginx" do
        expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

        get :download, params: { path:, format: }
      end

      context "and legacy_url_path has no format" do
        let(:legacy_url_path) { "/government/uploads/#{path}" }

        it "proxies asset to S3 via Nginx" do
          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, params: { path:, format: nil }
        end
      end
    end

    context "when asset is draft and uploaded" do
      let(:draft) { true }
      let(:state) { "uploaded" }
      let(:draft_assets_host) { AssetManager.govuk.draft_assets_host }

      context "when requested from host other than draft-assets" do
        before do
          request.headers["X-Forwarded-Host"] = "not-#{draft_assets_host}"
        end

        it "redirects to draft assets host" do
          get :download, params: { path:, format: }

          expect(controller).to redirect_to(host: draft_assets_host, path:, format:)
        end
      end

      context "when requested from draft-assets host" do
        before do
          request.headers["X-Forwarded-Host"] = draft_assets_host
          allow(controller).to receive(:proxy_to_s3_via_nginx)
        end

        it "requires authentication" do
          not_logged_in
          expect(controller).to receive(:authenticate_user!)

          get :download, params: { path:, format: }
        end

        it "proxies asset to S3 via Nginx as usual" do
          login_as_stub_user
          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, params: { path:, format: }
        end

        it "sets Cache-Control header to no-cache" do
          login_as_stub_user
          get :download, params: { path:, format: }

          expect(response.headers["Cache-Control"]).to eq("no-cache")
        end
      end
    end

    context "when asset has a redirect URL" do
      let(:state) { "uploaded" }
      let(:redirect_url) { "https://example.com/path/file.ext" }

      it "redirects to redirect URL" do
        get :download, params: { path:, format: }

        expect(response).to redirect_to(redirect_url)
      end
    end

    context "when asset has a replacement" do
      let(:state) { "uploaded" }
      let(:replacement) { FactoryBot.create(:uploaded_asset) }

      before do
        asset.replacement = replacement
      end

      it "redirects to replacement for asset" do
        get :download, params: { path:, format: }

        expected_url = "//#{AssetManager.govuk.assets_host}#{replacement.public_url_path}"
        expect(response).to redirect_to(expected_url)
      end

      it "responds with 301 moved permanently status" do
        get :download, params: { path:, format: }

        expect(response).to have_http_status(:moved_permanently)
      end

      it "sets the Cache-Control response header to 30 minutes" do
        get :download, params: { path:, format: }

        expect(response.headers["Cache-Control"]).to eq("max-age=1800, public")
      end

      context "and the replacement is draft" do
        before do
          replacement.update(draft: true)
        end

        it "serves the original asset when requested via something other than the draft-assets host" do
          request.headers["X-Forwarded-Host"] = "not-#{AssetManager.govuk.draft_assets_host}"

          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, params: { path:, format: }
        end

        it "redirects to the replacement asset when requested via the draft-assets host by a signed-in user" do
          request.headers["X-Forwarded-Host"] = AssetManager.govuk.draft_assets_host
          login_as_stub_user

          get :download, params: { path:, format: }

          expected_url = "//#{AssetManager.govuk.draft_assets_host}#{replacement.public_url_path}"
          expect(response).to redirect_to(expected_url)
        end
      end
    end

    context "when asset is draft and access limited" do
      let(:user) { FactoryBot.build(:user) }
      let(:state) { "uploaded" }

      before do
        allow(controller).to receive(:proxy_to_s3_via_nginx)
        allow(WhitehallAsset).to receive(:from_params).and_return(asset)
        request.headers["X-Forwarded-Host"] = AssetManager.govuk.draft_assets_host
        login_as user
      end

      it "grants access to a user who is authorised to view the asset" do
        allow(asset).to receive(:accessible_by?).with(user).and_return(true)

        get :download, params: { path:, format: }

        expect(response).to be_successful
      end

      it "denies access to a user who is not authorised to view the asset" do
        allow(asset).to receive(:accessible_by?).with(user).and_return(false)

        get :download, params: { path:, format: }

        expect(response).to be_forbidden
      end
    end

    context "with draft uploaded asset with auth_bypass_ids" do
      let(:user) { FactoryBot.build(:user) }
      let(:auth_bypass_id) { "bypass-id" }
      let(:asset) { FactoryBot.create(:uploaded_whitehall_asset, draft: true, auth_bypass_ids: [auth_bypass_id]) }
      let(:valid_token) do
        JWT.encode(
          { "sub" => auth_bypass_id },
          Rails.application.config_for(:secrets).jwt_auth_secret,
          "HS256",
        )
      end
      let(:token_with_draft_asset_manager_access) do
        JWT.encode(
          { "draft_asset_manager_access" => true },
          Rails.application.config_for(:secrets).jwt_auth_secret,
          "HS256",
        )
      end
      let(:state) { "uploaded" }

      before do
        allow(controller).to receive(:proxy_to_s3_via_nginx)
        allow(WhitehallAsset).to receive(:from_params).and_return(asset)
        request.headers["X-Forwarded-Host"] = AssetManager.govuk.draft_assets_host
        login_as user
      end

      context "when a user is not authenticated and has provided a valid token by query string" do
        before { not_logged_in }

        it "grants access to the file" do
          expect(controller).not_to receive(:authenticate_user!)
          get :download, params: { path:, format:, token: valid_token }
          expect(response).to be_successful
        end
      end

      context "when a user is not authenticated and has provided a valid token by cookie" do
        before { not_logged_in }

        it "grants access to the file" do
          request.cookies["auth_bypass_token"] = valid_token
          expect(controller).not_to receive(:authenticate_user!)
          get :download, params: { path:, format:, token: valid_token }
          expect(response).to be_successful
        end
      end

      context "when a user is not authenticated and has provided a valid token with draft_asset_manager_access" do
        before { not_logged_in }

        it "grants access to the file" do
          expect(controller).not_to receive(:authenticate_user!)
          get :download, params: { path:, format:, token: token_with_draft_asset_manager_access }
          expect(response).to be_successful
        end
      end

      context "when a user is not authenticated and has provided an invalid token" do
        before { not_logged_in }

        it "authenticates the user" do
          cookies["auth_bypass_token"] = "bad-token"
          expect(controller).to receive(:authenticate_user!)
          get :download, params: { path:, format: }
        end
      end

      context "when user is authenticated" do
        before { login_as_stub_user }

        it "grants access to the file" do
          get :download, params: { path:, format: }
          expect(response).to be_successful
        end
      end
    end

    context "when the asset doesn't contain a parent_document_url" do
      let(:state) { "uploaded" }

      before do
        allow(controller).to receive(:proxy_to_s3_via_nginx)
        allow(WhitehallAsset).to receive(:from_params).and_return(asset)
        asset.update!(parent_document_url: nil)
      end

      it "doesn't send a Link HTTP header" do
        get :download, params: { path:, format: }

        expect(response.headers["Link"]).to be_nil
      end
    end

    context "when the asset has a parent_document_url" do
      let(:state) { "uploaded" }

      before do
        allow(controller).to receive(:proxy_to_s3_via_nginx)
        allow(WhitehallAsset).to receive(:from_params).and_return(asset)
        asset.update!(parent_document_url: "https://parent-document-url")
      end

      it "sends the parent_document_url in a Link HTTP header" do
        get :download, params: { path:, format: }

        expect(response.headers["Link"]).to eql('<https://parent-document-url>; rel="up"')
      end
    end

    context "when asset is unscanned" do
      let(:state) { "unscanned" }

      include_examples "redirects to placeholders"
    end

    context "when asset is clean" do
      let(:state) { "clean" }

      include_examples "redirects to placeholders"
    end

    context "when asset is infected" do
      let(:state) { "infected" }

      it "responds with 404 Not Found" do
        get :download, params: { path:, format: }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a soft deleted file" do
      let(:state) { "uploaded" }

      before do
        asset.update!(deleted_at: Time.zone.now)
      end

      it "responds with 410 Gone status" do
        get :download, params: { path:, format: }

        expect(response).to have_http_status(:gone)
      end
    end
  end
end
