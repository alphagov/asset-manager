require "rails_helper"

RSpec.describe MediaController, type: :controller do
  describe "#proxy_to_s3_via_nginx?" do
    let(:proxy_to_s3_via_nginx) { false }
    let(:random_number_generator) { instance_double(Random) }
    let(:random_number) { 50 }

    before do
      allow(AssetManager).to receive(:proxy_percentage_of_asset_requests_to_s3_via_nginx)
        .and_return(proxy_percentage_of_asset_requests_to_s3_via_nginx)
      allow(controller).to receive(:params)
        .and_return(proxy_to_s3_via_nginx: proxy_to_s3_via_nginx)
      allow(Random).to receive(:new).and_return(random_number_generator)
      allow(random_number_generator).to receive(:rand).with(100).and_return(random_number)
    end

    context "when proxy_percentage_of_asset_requests_to_s3_via_nginx is not set" do
      let(:proxy_percentage_of_asset_requests_to_s3_via_nginx) { 0 }

      context "when proxy_to_s3_via_nginx is not set" do
        let(:proxy_to_s3_via_nginx) { false }

        it "returns falsey" do
          expect(controller.send(:proxy_to_s3_via_nginx?)).to be_falsey
        end
      end

      context "when proxy_to_s3_via_nginx is set" do
        let(:proxy_to_s3_via_nginx) { true }

        it "returns truthy" do
          expect(controller.send(:proxy_to_s3_via_nginx?)).to be_truthy
        end
      end

      context "even when random number generator returns its minimum value" do
        let(:random_number) { 0 }

        it "returns falsey" do
          expect(controller.send(:proxy_to_s3_via_nginx?)).to be_falsey
        end
      end
    end

    context "when proxy_percentage_of_asset_requests_to_s3_via_nginx is set to 25%" do
      let(:proxy_percentage_of_asset_requests_to_s3_via_nginx) { 25 }

      context "when random number generator returns a number less than 25" do
        let(:random_number) { 24 }

        it "returns truthy" do
          expect(controller.send(:proxy_to_s3_via_nginx?)).to be_truthy
        end
      end

      context "when random number generator returns a number equal to or more than 25" do
        let(:random_number) { 25 }

        it "returns falsey" do
          expect(controller.send(:proxy_to_s3_via_nginx?)).to be_falsey
        end
      end
    end

    context "when proxy_percentage_of_asset_requests_to_s3_via_nginx is set to 100%" do
      let(:proxy_percentage_of_asset_requests_to_s3_via_nginx) { 100 }

      context "even when proxy_to_s3_via_nginx is not set" do
        let(:proxy_to_s3_via_nginx) { false }

        it "returns truthy" do
          expect(controller.send(:proxy_to_s3_via_nginx?)).to be_truthy
        end
      end

      context "even when random number generator returns its maximum value" do
        let(:random_number) { 99 }

        it "returns truthy" do
          expect(controller.send(:proxy_to_s3_via_nginx?)).to be_truthy
        end
      end
    end
  end

  describe "GET 'download'" do
    let(:params) { { id: asset, filename: asset.filename } }

    before do
      allow(controller).to receive_messages(requested_via_private_vhost?: false)
    end

    context "with a valid clean file" do
      let(:asset) { FactoryGirl.create(:clean_asset) }

      it "responds with 200 OK" do
        get :download, params
        expect(response).to have_http_status(:ok)
      end

      it "sends the file using send_file" do
        expect(controller).to receive(:send_file).with(asset.file.path, disposition: "inline")
        allow(controller).to receive(:render) # prevent template_not_found errors because we intercepted send_file

        get :download, params
      end

      it "sets the Content-Type header based on the file extension" do
        get :download, params
        expect(response.headers["Content-Type"]).to eq("image/png")
      end

      it "sets Cache-Control header to expire in 24 hours and be publicly cacheable" do
        get :download, params

        expect(response.headers["Cache-Control"]).to eq("max-age=86400, public")
      end

      context "when proxy_to_s3_via_nginx? is truthy" do
        let(:cloud_storage) { double(:cloud_storage) }
        let(:presigned_url) { 'https://s3-host.test/presigned-url' }
        let(:last_modified) { Time.zone.parse("2017-01-01 00:00") }
        let(:content_disposition) { instance_double(ContentDispositionConfiguration) }
        let(:http_method) { 'GET' }

        before do
          allow(controller).to receive(:proxy_to_s3_via_nginx?).and_return(true)
          allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
          allow(cloud_storage).to receive(:presigned_url_for)
            .with(asset, http_method: http_method).and_return(presigned_url)
          allow(controller).to receive(:asset).and_return(asset)
          allow(asset).to receive(:etag).and_return("599ffda8-e169")
          allow(asset).to receive(:last_modified).and_return(last_modified)
          allow(asset).to receive(:content_type).and_return('content-type')
          allow(AssetManager).to receive(:content_disposition).and_return(content_disposition)
          allow(content_disposition).to receive(:header_for).with(asset).and_return("content-disposition")
        end

        it "responds with 200 OK" do
          get :download, params
          expect(response).to have_http_status(:ok)
        end

        it "sends ETag response header with quoted value" do
          get :download, params
          expect(response.headers["ETag"]).to eq(%{"599ffda8-e169"})
        end

        it "sends Last-Modified response header in HTTP time format" do
          get :download, params
          expect(response.headers["Last-Modified"]).to eq("Sun, 01 Jan 2017 00:00:00 GMT")
        end

        it "sends Content-Disposition response header based on asset filename" do
          get :download, params
          expect(response.headers["Content-Disposition"]).to eq("content-disposition")
        end

        it "sends Content-Type response header based on asset file extension" do
          get :download, params
          expect(response.headers["Content-Type"]).to eq("content-type")
        end

        it "instructs nginx to proxy the request to S3" do
          get :download, params
          expect(response.headers["X-Accel-Redirect"]).to match("/cloud-storage-proxy/#{presigned_url}")
        end

        context "and HTTP method is HEAD" do
          let(:http_method) { 'HEAD' }

          it "responds with 200 OK" do
            head :download, params
            expect(response).to have_http_status(:ok)
          end
        end
      end

      context "when the file name in the URL represents an old version" do
        let(:old_file_name) { "an_old_filename.pdf" }

        before do
          allow(Asset).to receive(:find).with(asset.id).and_return(asset)
          allow(asset).to receive(:filename_valid?).and_return(true)
        end

        it "redirects to the new file name" do
          get :download, id: asset, filename: old_file_name

          expect(response.location).to match(%r(\A/media/#{asset.id}/asset.png))
        end
      end

      context "when the file name in the URL is invalid" do
        let(:invalid_file_name) { "invalid_file_name.pdf" }

        it "responds with 404 Not Found" do
          get :download, id: asset, filename: invalid_file_name

          expect(response).to have_http_status(:not_found)
        end
      end
    end

    context "with an unscanned file" do
      let(:asset) { FactoryGirl.create(:asset) }

      it "responds with 404 Not Found" do
        get :download, params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an otherwise servable whitehall asset" do
      let(:path) { '/government/uploads/asset.png' }
      let(:asset) { FactoryGirl.create(:clean_whitehall_asset, legacy_url_path: path) }

      it "responds with 404 Not Found" do
        get :download, params
        expect(response).to have_http_status(:not_found)
      end
    end

    context "with an infected file" do
      let(:asset) { FactoryGirl.create(:infected_asset) }

      it "responds with 404 Not Found" do
        get :download, params
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
        get :download, id: restricted_asset, filename: 'asset.png'
        expect(response).to have_http_status(:not_found)
      end

      it "responds with 200 OK for unrestricted documents" do
        get :download, id: unrestricted_asset, filename: 'asset.png'
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

        get :download, id: asset, filename: 'asset.png'
      end

      it "responds with 404 Not Found for access-limited documents if the user has the wrong organisation" do
        user = FactoryGirl.create(:user, organisation_slug: 'incorrect-organisation-slug')
        login_as(user)

        get :download, id: asset, filename: 'asset.png'

        expect(response).to have_http_status(:not_found)
      end

      it "responds with 200 OK for access-limited documents if the user has the right organisation" do
        user = FactoryGirl.create(:user, organisation_slug: 'correct-organisation-slug')
        login_as(user)

        get :download, id: asset, filename: 'asset.png'

        expect(response).to have_http_status(:ok)
      end
    end

    context "with a soft deleted file" do
      let(:asset) { FactoryGirl.create(:deleted_asset) }

      before do
        get :download, params
      end

      it "responds with not found status" do
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
