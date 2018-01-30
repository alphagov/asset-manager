require 'rails_helper'

RSpec.describe BaseMediaController, type: :controller do
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
      get 'anything' => 'base_media#anything'
      get 'download' => 'base_media#download'
    end
  end

  it 'does not require sign-in permission by default' do
    expect(controller).not_to receive(:authenticate_user!)

    get :anything
  end

  context 'when requested from draft-assets host' do
    before do
      request.headers['X-Forwarded-Host'] = draft_assets_host
    end

    it 'does require sign-in permission' do
      expect(controller).to receive(:authenticate_user!)

      get :anything
    end
  end

  context 'when requested from host other than draft-assets' do
    before do
      request.headers['X-Forwarded-Host'] = "not-#{draft_assets_host}"
    end

    it 'does not require sign-in permission' do
      expect(controller).not_to receive(:authenticate_user!)

      get :anything
    end
  end

  describe '#proxy_to_s3_via_nginx' do
    let(:asset) { FactoryBot.build(:asset, id: '123') }
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
      get :download, params: { id: asset.id }

      expect(response).to have_http_status(:ok)
    end

    it 'sends ETag response header with quoted value' do
      get :download, params: { id: asset.id }

      expect(response.headers['ETag']).to eq(%{"599ffda8-e169"})
    end

    it 'sends Last-Modified response header in HTTP time format' do
      get :download, params: { id: asset.id }

      expect(response.headers['Last-Modified']).to eq('Sun, 01 Jan 2017 00:00:00 GMT')
    end

    it 'sends Content-Disposition response header based on asset filename' do
      get :download, params: { id: asset.id }

      expect(response.headers['Content-Disposition']).to eq('content-disposition')
    end

    it 'sends Content-Type response header based on asset file extension' do
      get :download, params: { id: asset.id }

      expect(response.headers['Content-Type']).to eq('content-type')
    end

    it 'instructs Nginx to proxy the request to S3' do
      get :download, params: { id: asset.id }

      expect(response.headers['X-Accel-Redirect']).to match("/cloud-storage-proxy/#{presigned_url}")
    end

    context 'and HTTP method is HEAD' do
      let(:http_method) { 'HEAD' }

      it 'responds with 200 OK' do
        head :download, params: { id: asset.id }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when a conditional request is made using an ETag that matches the asset ETag' do
      it 'does not instruct Nginx to proxy the request to S3' do
        request.headers['If-None-Match'] = %("#{asset.etag}")

        get :download, params: { id: asset.id }

        expect(response.headers).not_to include('X-Accel-Redirect')
      end
    end

    context 'when conditional request is made using an ETag that does not match the asset ETag' do
      it 'instructs Nginx to proxy the request to S3' do
        request.headers['If-None-Match'] = %("made-up-etag")

        get :download, params: { id: asset.id }

        expect(response.headers['X-Accel-Redirect']).to match("/cloud-storage-proxy/#{presigned_url}")
      end
    end

    context 'when a conditional request is made using a timestamp that matches the asset timestamp' do
      it 'does not instruct Nginx to proxy the request to S3' do
        request.headers['If-Modified-Since'] = asset.last_modified.httpdate

        get :download, params: { id: asset.id }

        expect(response.headers).not_to include('X-Accel-Redirect')
      end
    end

    context 'when a conditional request is made using a timestamp that is earlier than the asset timestamp' do
      it 'instructs Nginx to proxy the request to S3' do
        request.headers['If-Modified-Since'] = (asset.last_modified - 1.day).httpdate

        get :download, params: { id: asset.id }

        expect(response.headers['X-Accel-Redirect']).to match("/cloud-storage-proxy/#{presigned_url}")
      end
    end

    context 'when a conditional request is made using a timestamp that is later than the asset timestamp' do
      it 'does not instruct Nginx to proxy the request to S3' do
        request.headers['If-Modified-Since'] = (asset.last_modified + 1.day).httpdate

        get :download, params: { id: asset.id }

        expect(response.headers).not_to include('X-Accel-Redirect')
      end
    end

    context 'when a conditional request is made using an Etag and timestamp that match the asset' do
      it 'does not instruct Nginx to proxy the request to S3' do
        request.headers['If-None-Match'] = %("#{asset.etag}")
        request.headers['If-Modified-Since'] = asset.last_modified.httpdate

        get :download, params: { id: asset.id }

        expect(response.headers).not_to include('X-Accel-Redirect')
      end
    end

    context 'when a conditional request is made using an Etag that matches and timestamp that does not match the asset' do
      it 'instructs Nginx to proxy the request to S3' do
        request.headers['If-None-Match'] = %("#{asset.etag}")
        request.headers['If-Modified-Since'] = (asset.last_modified - 1.day).httpdate

        get :download, params: { id: asset.id }

        expect(response.headers['X-Accel-Redirect']).to match("/cloud-storage-proxy/#{presigned_url}")
      end
    end

    context 'when a conditional request is made using an Etag that does not match and a timestamp that matches the asset' do
      it 'instructs Nginx to proxy the request to S3' do
        request.headers['If-None-Match'] = 'made-up-etag'
        request.headers['If-Modified-Since'] = asset.last_modified.httpdate

        get :download, params: { id: asset.id }

        expect(response.headers['X-Accel-Redirect']).to match("/cloud-storage-proxy/#{presigned_url}")
      end
    end
  end
end
