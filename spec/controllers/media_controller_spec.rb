require "rails_helper"

RSpec.describe MediaController, type: :controller do
  describe "GET 'download'" do
    before do
      allow(controller).to receive_messages(requested_via_private_vhost?: false)
    end

    context "with a valid clean file" do
      let(:asset) { FactoryGirl.create(:clean_asset) }

      def do_get(extra_params = {})
        get :download, { id: asset.id.to_s, filename: asset.file.file.identifier }.merge(extra_params)
      end

      it "responds with 200 OK" do
        do_get
        expect(response).to have_http_status(:ok)
      end

      it "sends the file using send_file" do
        expect(controller).to receive(:send_file).with(asset.file.path, disposition: "inline")
        allow(controller).to receive(:render) # prevent template_not_found errors because we intercepted send_file

        do_get
      end

      it "sets the Content-Type header based on the file extension" do
        do_get
        expect(response.headers["Content-Type"]).to eq("image/png")
      end

      it "sets Cache-Control header to expire in 24 hours and be publicly cacheable" do
        do_get

        expect(response.headers["Cache-Control"]).to eq("max-age=86400, public")
      end

      context "when stream_from_s3 param is present" do
        let(:io) { StringIO.new('s3-object-data') }
        let(:cloud_storage) { double(:cloud_storage) }

        before do
          allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
          allow(cloud_storage).to receive(:load).with(asset).and_return(io)
        end

        it "responds with 200 OK" do
          do_get stream_from_s3: true
          expect(response).to have_http_status(:ok)
        end

        it "streams the asset to the client using send_data" do
          expect(controller).to receive(:send_data).with('s3-object-data', filename: 'asset.png', disposition: "inline")
          allow(controller).to receive(:render) # prevent template_not_found errors because we intercepted send_file

          do_get stream_from_s3: true
        end

        it "sets the Content-Type header based on the file extension" do
          do_get stream_from_s3: true
          expect(response.headers["Content-Type"]).to eq("image/png")
        end

        it "sets Cache-Control header to expire in 24 hours and be publicly cacheable" do
          do_get stream_from_s3: true

          expect(response.headers["Cache-Control"]).to eq("max-age=86400, public")
        end
      end

      context "when redirect_to_s3 param is present" do
        let(:cloud_storage) { double(:cloud_storage) }

        before do
          allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
          allow(cloud_storage).to receive(:public_url_for).with(asset).and_return('public-url')
        end

        it "responds with 302 Found (temporary redirect)" do
          do_get redirect_to_s3: true
          expect(response).to have_http_status(:found)
        end

        it "redirects to the public URL of the asset" do
          do_get redirect_to_s3: true
          expect(response).to redirect_to('public-url')
        end
      end

      context "when proxy_via_nginx param is present" do
        let(:cloud_storage) { double(:cloud_storage) }
        let(:presigned_url) { 'https://s3-host.test/presigned-url' }

        before do
          allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
          allow(cloud_storage).to receive(:presigned_url_for).with(asset).and_return(presigned_url)
        end

        it "responds with 200 OK" do
          do_get proxy_via_nginx: true
          expect(response).to have_http_status(:ok)
        end

        it "instructs nginx to proxy the request to S3" do
          do_get proxy_via_nginx: true
          expect(response.headers["X-Accel-Redirect"]).to match("/cloud-storage-proxy/#{presigned_url}")
        end
      end

      context "when config.stream_all_assets_from_s3 is true" do
        let(:io) { StringIO.new('s3-object-data') }
        let(:cloud_storage) { double(:cloud_storage) }

        before do
          allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
          allow(cloud_storage).to receive(:load).with(asset).and_return(io)
          allow(AssetManager).to receive(:stream_all_assets_from_s3).and_return(true)
        end

        it "responds with 200 OK" do
          do_get
          expect(response).to have_http_status(:ok)
        end

        it "streams the asset to the client using send_data" do
          expect(controller).to receive(:send_data).with('s3-object-data', filename: 'asset.png', disposition: "inline")
          allow(controller).to receive(:render) # prevent template_not_found errors because we intercepted send_file

          do_get
        end

        it "sets the Content-Type header based on the file extension" do
          do_get
          expect(response.headers["Content-Type"]).to eq("image/png")
        end

        it "sets Cache-Control header to expire in 24 hours and be publicly cacheable" do
          do_get

          expect(response.headers["Cache-Control"]).to eq("max-age=86400, public")
        end
      end

      context "when the file name in the URL represents an old version" do
        let(:old_file_name) { "an_old_filename.pdf" }

        before do
          allow(Asset).to receive(:find).with(asset.id.to_s).and_return(asset)
          allow(asset).to receive(:filename_valid?).and_return(true)
        end

        it "redirects to the new file name" do
          get :download, id: asset.id, filename: old_file_name

          expect(response.location).to match(%r(\A/media/#{asset.id}/asset.png))
        end
      end

      context "when the file name in the URL is invalid" do
        let(:invalid_file_name) { "invalid_file_name.pdf" }

        it "responds with 404 Not Found" do
          get :download, id: asset.id, filename: invalid_file_name

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "with an unscanned file" do
      let(:asset) { FactoryGirl.create(:asset) }

      it "responds with 404 Not Found" do
        get :download, id: asset.id.to_s, filename: asset.file.file.identifier
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an infected file" do
      let(:asset) { FactoryGirl.create(:infected_asset) }

      it "responds with 404 Not Found" do
        get :download, id: asset.id.to_s, filename: asset.file.file.identifier
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with a URL containing an invalid ID" do
      it "responds with 404 Not Found" do
        get :download, id: "1234556678895332452345", filename: "something.jpg"
        expect(response).to have_http_status(:not_found)
      end
    end

    context "access limiting on the public interface" do
      let(:restricted_asset) { FactoryGirl.create(:access_limited_asset, organisation_slug: 'example-slug') }
      let(:unrestricted_asset) { FactoryGirl.create(:clean_asset) }

      it "responds with 404 Not Found for access-limited documents" do
        get :download, id: restricted_asset.id.to_s, filename: 'asset.png'
        expect(response).to have_http_status(:not_found)
      end

      it "responds with 200 OK for unrestricted documents" do
        get :download, id: unrestricted_asset.id.to_s, filename: 'asset.png'
        expect(response).to have_http_status(:ok)
      end
    end

    context "access limiting on the private interface" do
      let(:asset) { FactoryGirl.create(:access_limited_asset, organisation_slug: 'correct-organisation-slug') }

      before do
        allow(controller).to receive_messages(requested_via_private_vhost?: true)
      end

      it "bounces anonymous users to sign-on" do
        expect(controller).to receive(:require_signin_permission!)

        get :download, id: asset.id.to_s, filename: 'asset.png'
      end

      it "responds with 404 Not Found for access-limited documents if the user has the wrong organisation" do
        user = FactoryGirl.create(:user, organisation_slug: 'incorrect-organisation-slug')
        login_as(user)

        get :download, id: asset.id.to_s, filename: 'asset.png'

        expect(response).to have_http_status(:not_found)
      end

      it "responds with 200 OK for access-limited documents if the user has the right organisation" do
        user = FactoryGirl.create(:user, organisation_slug: 'correct-organisation-slug')
        login_as(user)

        get :download, id: asset.id.to_s, filename: 'asset.png'

        expect(response).to have_http_status(:ok)
      end
    end

    context "with a soft deleted file" do
      let(:asset) { FactoryGirl.create(:deleted_asset) }

      before do
        get :download, id: asset.id.to_s, filename: asset.file.file.identifier
      end

      it "responds with not found status" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
