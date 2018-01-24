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
  end
end
