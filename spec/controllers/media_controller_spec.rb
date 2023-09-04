require "rails_helper"
RSpec.describe MediaController, type: :controller do
  describe "base controller actions" do
    let(:draft_assets_host) { AssetManager.govuk.draft_assets_host }

    controller do
      def anything
        head :ok
      end

      def download
        asset = Asset.find(params[:id])
        proxy_to_s3_via_nginx(asset)
      end
    end

    before do
      routes.draw do
        get "download" => "media#download"
      end
    end

    describe "#proxy_to_s3_via_nginx" do
      let(:asset) { FactoryBot.build(:asset, id: "123") }
      let(:cloud_storage) { instance_double(S3Storage) }
      let(:presigned_url) { "https://s3-host.test/presigned-url" }
      let(:last_modified) { Time.zone.parse("2017-01-01 00:00") }
      let(:content_disposition) { instance_double(ContentDispositionConfiguration) }
      let(:s3) { S3Configuration.build }
      let(:http_method) { "GET" }

      before do
        not_logged_in
        allow(Asset).to receive(:find).with(asset.id).and_return(asset)
        allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
        allow(cloud_storage).to receive(:presigned_url_for)
          .with(asset, http_method:).and_return(presigned_url)
        allow(asset).to receive(:etag).and_return("599ffda8-e169")
        allow(asset).to receive(:last_modified).and_return(last_modified)
        allow(AssetManager).to receive(:content_disposition).and_return(content_disposition)
        allow(content_disposition).to receive(:header_for).with(asset).and_return("content-disposition")
        allow(AssetManager).to receive(:s3).and_return(s3)
      end

      context "when using real s3 in non-local environment" do
        before do
          allow(s3).to receive(:fake?).and_return(false)
        end

        shared_examples "a download response" do
          it "instructs Nginx to proxy the request to S3" do
            get :download, params: { id: asset.id }

            expect(response.headers["X-Accel-Redirect"]).to match("/cloud-storage-proxy/#{presigned_url}")
          end

          it "returns an ok response" do
            get :download, params: { id: asset.id }

            expect(response).to have_http_status(:ok)
          end
        end

        shared_examples "a not modified response" do
          it "does not instruct Nginx to proxy the request to S3" do
            get :download, params: { id: asset.id }

            expect(response.headers).not_to include("X-Accel-Redirect")
          end

          it "returns a not modified response" do
            get :download, params: { id: asset.id }

            expect(response).to have_http_status(:not_modified)
          end
        end

        it "sends ETag response header with quoted value" do
          get :download, params: { id: asset.id }

          expect(response.headers["ETag"]).to eq(%("599ffda8-e169"))
        end

        it "sends Last-Modified response header in HTTP time format" do
          get :download, params: { id: asset.id }

          expect(response.headers["Last-Modified"]).to eq("Sun, 01 Jan 2017 00:00:00 GMT")
        end

        it "sends Content-Disposition response header based on asset filename" do
          get :download, params: { id: asset.id }

          expect(response.headers["Content-Disposition"]).to eq("content-disposition")
        end

        it "sends an Asset's content_type when one is set" do
          allow(asset).to receive(:content_type).and_return("image/jpeg")
          get :download, params: { id: asset.id }

          expect(response.headers["Content-Type"]).to eq("image/jpeg")
        end

        it "determines an Asset's content_type by filename when it is not set" do
          allow(asset).to receive(:content_type).and_return(nil)
          allow(asset).to receive(:filename).and_return("file.pdf")
          get :download, params: { id: asset.id }

          expect(response.headers["Content-Type"]).to eq("application/pdf")
        end

        context "when there aren't conditional headers" do
          it_behaves_like "a download response"
        end

        context "when a conditional request is made using an ETag that matches the asset ETag" do
          before { request.headers["If-None-Match"] = %("#{asset.etag}") }

          it_behaves_like "a not modified response"
        end

        context "when conditional request is made using an ETag that does not match the asset ETag" do
          before { request.headers["If-None-Match"] = %("made-up-etag") }

          it_behaves_like "a download response"
        end

        context "when a conditional request is made using a timestamp that matches the asset timestamp" do
          before do
            request.headers["If-Modified-Since"] = asset.last_modified.httpdate
          end

          it_behaves_like "a not modified response"
        end

        context "when a conditional request is made using a timestamp that is earlier than the asset timestamp" do
          before do
            request.headers["If-Modified-Since"] = (asset.last_modified - 1.day).httpdate
          end

          it_behaves_like "a download response"
        end

        context "when a conditional request is made using a timestamp that is later than the asset timestamp" do
          before do
            request.headers["If-Modified-Since"] = (asset.last_modified + 1.day).httpdate
          end

          it_behaves_like "a not modified response"
        end

        context "when a conditional request is made using an Etag and timestamp that match the asset" do
          before do
            request.headers["If-None-Match"] = %("#{asset.etag}")
            request.headers["If-Modified-Since"] = asset.last_modified.httpdate
          end

          it_behaves_like "a not modified response"
        end

        context "when a conditional request is made using an Etag that matches and timestamp that does not match the asset" do
          before do
            request.headers["If-None-Match"] = %("#{asset.etag}")
            request.headers["If-Modified-Since"] = (asset.last_modified - 1.day).httpdate
          end

          it_behaves_like "a download response"
        end

        context "when a conditional request is made using an Etag that does not match and a timestamp that matches the asset" do
          before do
            request.headers["If-None-Match"] = "made-up-etag"
            request.headers["If-Modified-Since"] = asset.last_modified.httpdate
          end

          it_behaves_like "a download response"
        end
      end

      context "when using fake s3 in local environment" do
        before do
          allow(s3).to receive(:fake?).and_return(true)
        end

        it "redirects to presigned fake s3 url directly instead of Nginx proxy" do
          get :download, params: { id: asset.id }

          expected_url = presigned_url
          expect(controller).to redirect_to expected_url
        end
      end
    end
  end

  describe "GET 'download'" do
    before do
      allow(AssetManager).to receive(:s3).and_return(s3)
      allow(s3).to receive(:fake?).and_return(false)
      not_logged_in
    end

    let(:params) { { params: { id: asset, filename: asset.filename } } }
    let(:s3) { S3Configuration.build }

    context "with a valid uploaded file" do
      let(:asset) { FactoryBot.create(:uploaded_asset) }

      it "proxies asset to S3 via Nginx" do
        expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

        get :download, **params
      end

      it "sets Cache-Control header to expire in 30 minutes and be publicly cacheable" do
        get :download, **params

        expect(response.headers["Cache-Control"]).to eq("max-age=1800, public")
      end

      context "when the file name in the URL represents an old version" do
        let(:old_file_name) { "an_old_filename.pdf" }
        let(:scope) { class_double(Asset) }

        before do
          allow(Asset).to receive(:undeleted).and_return(scope)
          allow(scope).to receive(:find).with(asset.id).and_return(asset)
          allow(asset).to receive(:filename_valid?).and_return(true)
        end

        it "redirects to the new file name" do
          get :download, params: { id: asset, filename: old_file_name }

          expect(response.location).to match(download_media_path(id: asset, filename: "asset.png"))
        end
      end

      context "when the file name in the URL is invalid" do
        let(:invalid_file_name) { "invalid_file_name.pdf" }

        it "responds with 404 Not Found" do
          get :download, params: { id: asset, filename: invalid_file_name }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "with draft uploaded asset" do
      let(:asset) { FactoryBot.create(:uploaded_asset, draft: true) }
      let(:draft_assets_host) { AssetManager.govuk.draft_assets_host }
      let(:internal_host) { URI.parse(Plek.find("asset-manager")).host }

      context "when requested from host other than draft-assets" do
        before do
          request.headers["X-Forwarded-Host"] = "not-#{draft_assets_host}"
        end

        it "redirects to draft assets host" do
          get :download, **params

          expected_url = "http://#{draft_assets_host}#{asset.public_url_path}"
          expect(controller).to redirect_to expected_url
        end
      end

      context "when requested from host other than internal host" do
        before do
          request.headers["X-Forwarded-Host"] = "not-#{internal_host}"
        end

        it "redirects to draft assets host" do
          get :download, **params

          expected_url = "http://#{draft_assets_host}#{asset.public_url_path}"
          expect(controller).to redirect_to expected_url
        end
      end

      context "when requested from draft-assets host and not authenticated" do
        before do
          request.headers["X-Forwarded-Host"] = draft_assets_host
          allow(controller).to receive(:authenticate_user!)
        end

        it "requires authentication" do
          expect(controller).to receive(:authenticate_user!)

          get :download, **params
        end
      end

      context "when requested from internal host and not authenticated" do
        before do
          request.headers["X-Forwarded-Host"] = internal_host
          allow(controller).to receive(:authenticate_user!)
        end

        it "requires authentication" do
          expect(controller).to receive(:authenticate_user!)

          get :download, **params
        end
      end

      context "when requested from draft-assets host and authenticated" do
        before do
          request.headers["X-Forwarded-Host"] = draft_assets_host
          login_as_stub_user
          allow(controller).to receive(:proxy_to_s3_via_nginx)
        end

        it "proxies asset to S3 via Nginx as usual" do
          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, **params
        end

        it "sets Cache-Control header to no-cache" do
          get :download, **params

          expect(response.headers["Cache-Control"]).to eq("no-cache")
        end
      end

      context "when requested from internal host and authenticated" do
        before do
          request.headers["X-Forwarded-Host"] = internal_host
          login_as_stub_user
          allow(controller).to receive(:proxy_to_s3_via_nginx)
        end

        it "proxies asset to S3 via Nginx as usual" do
          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, **params
        end

        it "sets Cache-Control header to no-cache" do
          get :download, **params

          expect(response.headers["Cache-Control"]).to eq("no-cache")
        end
      end

      context "when the file name in the URL is invalid and the user is not authenticated" do
        let(:invalid_file_name) { "invalid_file_name.pdf" }

        before do
          request.headers["X-Forwarded-Host"] = draft_assets_host
          allow(controller).to receive(:authenticate_user!)
        end

        it "requires authentication" do
          expect(controller).to receive(:authenticate_user!)

          get :download, params: { id: asset, filename: invalid_file_name }
        end
      end

      context "when the file name in the URL is invalid and the user is authenticated" do
        let(:invalid_file_name) { "invalid_file_name.pdf" }

        before do
          request.headers["X-Forwarded-Host"] = draft_assets_host
          login_as_stub_user
        end

        it "responds with 404 Not Found" do
          get :download, params: { id: asset, filename: invalid_file_name }

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "with an access limited draft asset" do
      context "when a user is authenticated" do
        let(:user) { FactoryBot.build(:user) }
        let(:asset) { FactoryBot.create(:uploaded_asset, draft: true) }
        let(:scope) { class_double(Asset) }

        before do
          allow(Asset).to receive(:undeleted).and_return(scope)
          allow(scope).to receive(:find).with(asset.id).and_return(asset)
          request.headers["X-Forwarded-Host"] = AssetManager.govuk.draft_assets_host
          login_as user
        end

        it "grants access to a user who is authorised to view the asset" do
          allow(asset).to receive(:accessible_by?).with(user).and_return(true)

          get :download, **params

          expect(response).to be_successful
        end

        it "denies access to a user who is not authorised to view the asset" do
          allow(asset).to receive(:accessible_by?).with(user).and_return(false)

          get :download, **params

          expect(response).to be_forbidden
        end
      end

      context "when a user is not authenticated" do
        let(:asset) { FactoryBot.create(:uploaded_asset, draft: true, access_limited: %w[id]) }
        let(:token_with_draft_asset_manager_access) do
          JWT.encode(
            { "draft_asset_manager_access" => true },
            Rails.application.secrets.jwt_auth_secret,
            "HS256",
          )
        end

        before { not_logged_in }

        it "denies access to a user who has draft_asset_manager_access" do
          allow(controller).to receive(:requested_from_draft_assets_host?).and_return(true)
          allow(controller).to receive(:has_bypass_id_for_asset?).with(any_args).and_return(false)

          query_params = params.tap { |p| p[:params].merge!(token: token_with_draft_asset_manager_access) }

          allow(controller).to receive(:authenticate_user!).and_raise("requires authentication")

          expect { get :download, **query_params }.to raise_error("requires authentication")
        end
      end
    end

    context "with draft uploaded asset with auth_bypass_ids" do
      before do
        request.headers["X-Forwarded-Host"] = AssetManager.govuk.draft_assets_host
      end

      let(:auth_bypass_id) { "bypass-id" }
      let(:asset) { FactoryBot.create(:uploaded_asset, draft: true, auth_bypass_ids: [auth_bypass_id]) }
      let(:valid_token) do
        JWT.encode(
          { "sub" => auth_bypass_id },
          Rails.application.secrets.jwt_auth_secret,
          "HS256",
        )
      end
      let(:token_with_draft_asset_manager_access) do
        JWT.encode(
          { "draft_asset_manager_access" => true },
          Rails.application.secrets.jwt_auth_secret,
          "HS256",
        )
      end

      context "when a user is not authenticated and has provided a valid token by query string" do
        before { not_logged_in }

        it "grants access to the file" do
          expect(controller).not_to receive(:authenticate_user!)
          query_params = params.tap { |p| p[:params].merge!(token: valid_token) }
          get :download, **query_params
          expect(response).to be_successful
        end
      end

      context "when a user is not authenticated and has provided a valid token by cookie" do
        before { not_logged_in }

        it "grants access to the file" do
          request.cookies["auth_bypass_token"] = valid_token
          expect(controller).not_to receive(:authenticate_user!)
          get :download, **params
          expect(response).to be_successful
        end
      end

      context "when a user is not authenticated and has provided a valid token with draft_asset_manager_access" do
        before { not_logged_in }

        it "grants access to the file" do
          expect(controller).not_to receive(:authenticate_user!)
          query_params = params.tap { |p| p[:params].merge!(token: token_with_draft_asset_manager_access) }
          get :download, **query_params
          expect(response).to be_successful
        end
      end

      context "when a user is not authenticated and has provided an invalid token" do
        before { not_logged_in }

        it "authenticates the user" do
          cookies["auth_bypass_token"] = "bad-token"
          expect(controller).to receive(:authenticate_user!)
          get :download, **params
        end
      end

      context "when user is authenticated" do
        before { login_as_stub_user }

        it "grants access to the file" do
          get :download, **params
          expect(response).to be_successful
        end
      end
    end

    context "with an unscanned file" do
      let(:asset) { FactoryBot.create(:asset) }

      it "responds with 404 Not Found" do
        get :download, **params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a valid clean file" do
      let(:asset) { FactoryBot.create(:clean_asset) }

      it "responds with 404 Not Found" do
        get :download, **params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an otherwise servable whitehall asset" do
      let(:path) { "/government/uploads/asset.png" }
      let(:asset) { FactoryBot.create(:uploaded_whitehall_asset, legacy_url_path: path) }

      it "responds with 404 Not Found" do
        get :download, **params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an infected file" do
      let(:asset) { FactoryBot.create(:infected_asset) }

      it "responds with 404 Not Found" do
        get :download, **params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a URL containing an invalid ID" do
      it "responds with 404 Not Found" do
        get :download, params: { id: "1234556678895332452345", filename: "something.jpg" }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a soft deleted file" do
      let(:asset) { FactoryBot.create(:deleted_asset) }

      before do
        get :download, **params
      end

      it "responds with not found status" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when asset has a redirect URL" do
      let(:redirect_url) { "https://example.com/path/file.ext" }
      let(:asset) { FactoryBot.create(:uploaded_asset, redirect_url:) }

      it "redirects to redirect URL" do
        get :download, **params

        expect(response).to redirect_to(redirect_url)
      end
    end

    context "when asset has a replacement" do
      let(:replacement) { FactoryBot.create(:uploaded_asset) }
      let(:asset) { FactoryBot.create(:uploaded_asset, replacement:) }

      it "redirects to replacement for asset" do
        get :download, **params

        expected_url = "//#{AssetManager.govuk.assets_host}#{replacement.public_url_path}"
        expect(response).to redirect_to(expected_url)
      end

      it "responds with 301 moved permanently status" do
        get :download, **params

        expect(response).to have_http_status(:moved_permanently)
      end

      it "sets the Cache-Control response header to 30 minutes" do
        get :download, **params

        expect(response.headers["Cache-Control"]).to eq("max-age=1800, public")
      end

      context "and the asset is draft and is requested from not the draft host" do
        before do
          request.headers["X-Forwarded-Host"] = "not-#{AssetManager.govuk.draft_assets_host}"
          asset.draft = true
          asset.save!(validate: false)
        end

        it "redirects if the replacement is live" do
          get :download, **params

          expected_url = "//#{AssetManager.govuk.assets_host}#{replacement.public_url_path}"
          expect(response).to redirect_to(expected_url)
        end
      end

      context "and the replacement is draft" do
        before do
          replacement.update(draft: true)
        end

        it "serves the original asset when requested via something other than the draft-assets host" do
          request.headers["X-Forwarded-Host"] = "not-#{AssetManager.govuk.draft_assets_host}"

          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, **params
        end

        it "redirects to the replacement asset when requested via the draft-assets host by a signed-in user" do
          request.headers["X-Forwarded-Host"] = AssetManager.govuk.draft_assets_host
          login_as_stub_user

          get :download, **params

          expected_url = "//#{AssetManager.govuk.draft_assets_host}#{replacement.public_url_path}"
          expect(response).to redirect_to expected_url
        end
      end
    end

    context "when the asset doesn't contain a parent_document_url" do
      let(:asset) { FactoryBot.create(:uploaded_asset) }

      before do
        asset.update(parent_document_url: nil)
      end

      it "doesn't send a Link HTTP header" do
        get :download, **params

        expect(response.headers["Link"]).to be_nil
      end
    end

    context "when the asset has a parent_document_url" do
      let(:asset) { FactoryBot.create(:uploaded_asset) }

      before do
        asset.parent_document_url = "parent-document-url"
        asset.save!(validate: false)
      end

      it "sends the parent_document_url in a Link HTTP header" do
        get :download, **params

        expect(response.headers["Link"]).to eql('<parent-document-url>; rel="up"')
      end
    end
  end
end
