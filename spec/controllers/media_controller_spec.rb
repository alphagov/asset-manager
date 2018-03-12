require "rails_helper"

RSpec.describe MediaController, type: :controller do
  describe "GET 'download'" do
    let(:params) { { params: { id: asset, filename: asset.filename } } }

    context "with a valid uploaded file" do
      let(:asset) { FactoryBot.create(:uploaded_asset) }

      it "proxies asset to S3 via Nginx" do
        expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

        get :download, params
      end

      it "sets Cache-Control header to expire in 24 hours and be publicly cacheable" do
        get :download, params

        expect(response.headers["Cache-Control"]).to eq("max-age=86400, public")
      end

      context "when the file name in the URL represents an old version" do
        let(:old_file_name) { "an_old_filename.pdf" }

        before do
          allow(Asset).to receive(:find).with(asset.id).and_return(asset)
          allow(asset).to receive(:filename_valid?).and_return(true)
        end

        it "redirects to the new file name" do
          get :download, params: { id: asset, filename: old_file_name }

          expect(response.location).to match(%r(\A/media/#{asset.id}/asset.png))
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

    context 'with draft uploaded asset' do
      let(:asset) { FactoryBot.create(:uploaded_asset, draft: true) }
      let(:draft_assets_host) { AssetManager.govuk.draft_assets_host }

      context 'when requested from host other than draft-assets' do
        before do
          request.headers['X-Forwarded-Host'] = "not-#{draft_assets_host}"
        end

        it 'redirects to draft assets host' do
          get :download, params

          expected_url = "http://#{draft_assets_host}#{asset.public_url_path}"
          expect(controller).to redirect_to expected_url
        end
      end

      context 'when requested from draft-assets host' do
        before do
          request.headers['X-Forwarded-Host'] = draft_assets_host
          allow(controller).to receive(:authenticate_user!)
          allow(controller).to receive(:proxy_to_s3_via_nginx)
        end

        it 'requires authentication' do
          expect(controller).to receive(:authenticate_user!)

          get :download, params
        end

        it 'proxies asset to S3 via Nginx as usual' do
          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, params
        end

        it "sets Cache-Control header to no-cache" do
          get :download, params

          expect(response.headers["Cache-Control"]).to eq("no-cache")
        end
      end
    end

    context 'with an access limited draft asset' do
      let(:user) { FactoryBot.build(:user) }
      let(:asset) { FactoryBot.create(:uploaded_asset, draft: true) }

      before do
        allow(Asset).to receive(:find).with(asset.id).and_return(asset)
        request.headers['X-Forwarded-Host'] = AssetManager.govuk.draft_assets_host
        login_as user
      end

      it 'grants access to a user who is authorised to view the asset' do
        allow(asset).to receive(:accessible_by?).with(user).and_return(true)

        get :download, params

        expect(response).to be_success
      end

      it 'denies access to a user who is not authorised to view the asset' do
        allow(asset).to receive(:accessible_by?).with(user).and_return(false)

        get :download, params

        expect(response).to be_forbidden
      end
    end

    context "with an unscanned file" do
      let(:asset) { FactoryBot.create(:asset) }

      it "responds with 404 Not Found" do
        get :download, params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a valid clean file" do
      let(:asset) { FactoryBot.create(:clean_asset) }

      it "responds with 404 Not Found" do
        get :download, params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an otherwise servable whitehall asset" do
      let(:path) { '/government/uploads/asset.png' }
      let(:asset) { FactoryBot.create(:uploaded_whitehall_asset, legacy_url_path: path) }

      it "responds with 404 Not Found" do
        get :download, params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an infected file" do
      let(:asset) { FactoryBot.create(:infected_asset) }

      it "responds with 404 Not Found" do
        get :download, params
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
        get :download, params
      end

      it "responds with not found status" do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when asset has a redirect URL' do
      let(:redirect_url) { 'https://example.com/path/file.ext' }
      let(:asset) { FactoryBot.create(:uploaded_asset, redirect_url: redirect_url) }

      it 'redirects to redirect URL' do
        get :download, params

        expect(response).to redirect_to(redirect_url)
      end
    end

    context 'when asset has a replacement' do
      let(:replacement) { FactoryBot.create(:uploaded_asset) }
      let(:asset) { FactoryBot.create(:uploaded_asset, replacement: replacement) }

      it 'redirects to replacement for asset' do
        get :download, params

        expect(response).to redirect_to(replacement.public_url_path)
      end

      it 'responds with 301 moved permanently status' do
        get :download, params

        expect(response).to have_http_status(:moved_permanently)
      end

      it 'sets the Cache-Control response header to 24 hours' do
        get :download, params

        expect(response.headers['Cache-Control']).to eq('max-age=86400, public')
      end
    end

    context "when the asset doesn't contain a parent_document_url" do
      let(:asset) { FactoryBot.create(:uploaded_asset) }

      before do
        asset.update_attribute(:parent_document_url, nil)
      end

      it "doesn't send a Link HTTP header" do
        get :download, params

        expect(response.headers['Link']).to be_nil
      end
    end

    context 'when the asset has a parent_document_url' do
      let(:asset) { FactoryBot.create(:uploaded_asset) }

      before do
        asset.update_attribute(:parent_document_url, 'parent-document-url')
      end

      it 'sends the parent_document_url in a Link HTTP header' do
        get :download, params

        expect(response.headers['Link']).to eql('<parent-document-url>; rel="up"')
      end
    end
  end
end
