require 'rails_helper'

RSpec.describe BaseMediaController, type: :controller do
  controller do
    def anything
      render nothing: true
    end

    def download
      asset = Asset.find(params[:id])
      serve_from_nfs_via_nginx(asset)
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
