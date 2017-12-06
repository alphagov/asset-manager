require "rails_helper"

RSpec.describe MediaController, type: :controller do
  describe "GET 'download'" do
    let(:params) { { params: { id: asset, filename: asset.filename } } }

    before do
      allow(controller).to receive_messages(requested_via_private_vhost?: false)
    end

    context "with a valid clean file" do
      let(:asset) { FactoryBot.create(:clean_asset) }

      context "when proxy_to_s3_via_nginx? is falsey (default)" do
        before do
          allow(controller).to receive(:proxy_to_s3_via_nginx?).and_return(false)
          allow(controller).to receive(:render)
        end

        it "serves asset from NFS via Nginx" do
          expect(controller).to receive(:serve_from_nfs_via_nginx).with(asset)

          get :download, params
        end

        it "sets Cache-Control header to expire in 24 hours and be publicly cacheable" do
          get :download, params

          expect(response.headers["Cache-Control"]).to eq("max-age=86400, public")
        end
      end

      context "when proxy_to_s3_via_nginx? is truthy" do
        before do
          allow(controller).to receive(:proxy_to_s3_via_nginx?).and_return(true)
          allow(controller).to receive(:render)
        end

        it "proxies asset to S3 via Nginx" do
          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, params
        end

        it "sets Cache-Control header to expire in 24 hours and be publicly cacheable" do
          get :download, params

          expect(response.headers["Cache-Control"]).to eq("max-age=86400, public")
        end
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

    context "with an unscanned file" do
      let(:asset) { FactoryBot.create(:asset) }

      it "responds with 404 Not Found" do
        get :download, params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an otherwise servable whitehall asset" do
      let(:path) { '/government/uploads/asset.png' }
      let(:asset) { FactoryBot.create(:clean_whitehall_asset, legacy_url_path: path) }

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

    context "access limiting on the public interface" do
      let(:restricted_asset) { FactoryBot.create(:access_limited_asset, organisation_slug: 'example-slug') }
      let(:unrestricted_asset) { FactoryBot.create(:clean_asset) }

      it "responds with 404 Not Found for access-limited documents" do
        get :download, params: { id: restricted_asset, filename: 'asset.png' }
        expect(response).to have_http_status(:not_found)
      end

      it "responds with 200 OK for unrestricted documents" do
        get :download, params: { id: unrestricted_asset, filename: 'asset.png' }
        expect(response).to have_http_status(:ok)
      end
    end

    context "access limiting on the private interface" do
      let(:asset) { FactoryBot.create(:access_limited_asset, organisation_slug: 'correct-organisation-slug') }

      before do
        allow(controller).to receive_messages(requested_via_private_vhost?: true)
      end

      it "bounces anonymous users to sign-on" do
        expect(controller).to receive(:require_signin_permission!)

        get :download, params: { id: asset, filename: 'asset.png' }
      end

      it "responds with 404 Not Found for access-limited documents if the user has the wrong organisation" do
        user = FactoryBot.create(:user, organisation_slug: 'incorrect-organisation-slug')
        login_as(user)

        get :download, params: { id: asset, filename: 'asset.png' }

        expect(response).to have_http_status(:not_found)
      end

      it "responds with 200 OK for access-limited documents if the user has the right organisation" do
        user = FactoryBot.create(:user, organisation_slug: 'correct-organisation-slug')
        login_as(user)

        get :download, params: { id: asset, filename: 'asset.png' }

        expect(response).to have_http_status(:ok)
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
  end

  describe '#proxy_percentage_of_asset_requests_to_s3_via_nginx' do
    let(:mainstream_percentage) { 55 }

    before do
      allow(AssetManager)
        .to receive(:proxy_percentage_of_asset_requests_to_s3_via_nginx)
        .and_return(mainstream_percentage)
    end

    it 'returns the percentage of Mainstream requests to proxy to S3' do
      expect(controller.send(:proxy_percentage_of_asset_requests_to_s3_via_nginx))
        .to eq(mainstream_percentage)
    end
  end
end
