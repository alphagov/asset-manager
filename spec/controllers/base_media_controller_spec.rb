require 'rails_helper'

RSpec.describe BaseMediaController, type: :controller do
  controller do
    def anything
      render nothing: true
    end

    def download
      asset = Asset.find(params[:id])
      if params[:proxy_to_s3_via_nginx]
        proxy_to_s3_via_nginx(asset)
      else
        serve_from_nfs_via_nginx(asset)
      end
    end
  end

  before do
    routes.draw do
      get 'anything' => 'base_media#anything'
      get 'download' => 'base_media#download'
    end
  end

  it 'does not require sign-in permission' do
    expect(controller).not_to receive(:require_signin_permission!)

    get :anything
  end

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

  describe '#proxy_to_s3_via_nginx' do
    let(:asset) { FactoryGirl.build(:asset, id: '123') }
    let(:cloud_storage) { double(:cloud_storage) }
    let(:presigned_url) { 'https://s3-host.test/presigned-url' }
    let(:last_modified) { Time.zone.parse('2017-01-01 00:00') }
    let(:content_disposition) { instance_double(ContentDispositionConfiguration) }
    let(:http_method) { 'GET' }

    before do
      allow(Asset).to receive(:find).with(asset.id).and_return(asset)
      allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
      allow(cloud_storage).to receive(:presigned_url_for)
        .with(asset, http_method: http_method).and_return(presigned_url)
      allow(asset).to receive(:etag).and_return('599ffda8-e169')
      allow(asset).to receive(:last_modified).and_return(last_modified)
      allow(asset).to receive(:content_type).and_return('content-type')
      allow(AssetManager).to receive(:content_disposition).and_return(content_disposition)
      allow(content_disposition).to receive(:header_for).with(asset).and_return('content-disposition')
    end

    it 'responds with 200 OK' do
      get :download, id: asset.id, proxy_to_s3_via_nginx: true

      expect(response).to have_http_status(:ok)
    end

    it 'sends ETag response header with quoted value' do
      get :download, id: asset.id, proxy_to_s3_via_nginx: true

      expect(response.headers['ETag']).to eq(%{"599ffda8-e169"})
    end

    it 'sends Last-Modified response header in HTTP time format' do
      get :download, id: asset.id, proxy_to_s3_via_nginx: true

      expect(response.headers['Last-Modified']).to eq('Sun, 01 Jan 2017 00:00:00 GMT')
    end

    it 'sends Content-Disposition response header based on asset filename' do
      get :download, id: asset.id, proxy_to_s3_via_nginx: true

      expect(response.headers['Content-Disposition']).to eq('content-disposition')
    end

    it 'sends Content-Type response header based on asset file extension' do
      get :download, id: asset.id, proxy_to_s3_via_nginx: true

      expect(response.headers['Content-Type']).to eq('content-type')
    end

    it 'instructs Nginx to proxy the request to S3' do
      get :download, id: asset.id, proxy_to_s3_via_nginx: true

      expect(response.headers['X-Accel-Redirect']).to match("/cloud-storage-proxy/#{presigned_url}")
    end

    context 'and HTTP method is HEAD' do
      let(:http_method) { 'HEAD' }

      it 'responds with 200 OK' do
        head :download, id: asset.id, proxy_to_s3_via_nginx: true

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe '#serve_from_nfs_via_nginx' do
    let(:asset) { FactoryGirl.build(:asset, id: '123') }
    let(:content_disposition) { instance_double(ContentDispositionConfiguration) }

    before do
      allow(Asset).to receive(:find).with(asset.id).and_return(asset)
      allow(AssetManager).to receive(:content_disposition).and_return(content_disposition)
      allow(content_disposition).to receive(:type).and_return('content-disposition')
    end

    it 'responds with 200 OK' do
      get :download, id: asset.id

      expect(response).to have_http_status(:ok)
    end

    it 'uses send_file to instruct Nginx to serve file from NFS' do
      allow(controller).to receive(:render)
      expect(controller).to receive(:send_file).with(asset.file.path, anything)

      get :download, id: asset.id
    end

    it 'sets Content-Disposition header to value in configuration' do
      allow(controller).to receive(:render)
      expect(controller).to receive(:send_file).with(anything, include(disposition: 'content-disposition'))

      get :download, id: asset.id
    end
  end
end
