require "rails_helper"

RSpec.describe WhitehallMediaController, type: :controller do
  include ActionView::Helpers::AssetUrlHelper

  describe '#download' do
    let(:path) { 'path/to/asset' }
    let(:format) { 'png' }
    let(:legacy_url_path) { "/government/uploads/#{path}.#{format}" }

    before do
      allow(WhitehallAsset).to receive(:find_by).with(legacy_url_path: legacy_url_path).and_return(asset)
    end

    context 'when asset is clean' do
      let(:asset) { FactoryGirl.build(:whitehall_asset, legacy_url_path: legacy_url_path, state: 'clean') }
      let(:content_disposition) { instance_double(ContentDispositionConfiguration) }

      before do
        allow(AssetManager).to receive(:content_disposition).and_return(content_disposition)
        allow(content_disposition).to receive(:type).and_return('content-disposition')
        allow(asset).to receive(:content_type).and_return('content-type')
        allow(controller).to receive(:render)
      end

      it 'uses send_file to instruct Nginx to serve file from NFS' do
        expect(controller).to receive(:send_file).with(asset.file.path, anything)

        get :download, path: path, format: format
      end

      it 'sets Content-Disposition header to value in configuration' do
        expect(controller).to receive(:send_file).with(anything, include(disposition: 'content-disposition'))

        get :download, path: path, format: format
      end
    end

    context 'when asset is unscanned image' do
      let(:asset) { FactoryGirl.build(:whitehall_asset, state: 'unscanned') }

      before do
        allow(asset).to receive(:image?).and_return(true)
      end

      it 'redirects to thumbnail-placeholder image' do
        get :download, path: path, format: format

        expect(controller).to redirect_to(image_path('thumbnail-placeholder.png'))
      end
    end

    context 'when asset is unscanned non-image' do
      let(:asset) { FactoryGirl.build(:whitehall_asset, state: 'unscanned') }

      before do
        allow(asset).to receive(:image?).and_return(false)
      end

      it 'redirects to government placeholder page' do
        get :download, path: path, format: format

        expect(controller).to redirect_to('/government/placeholder')
      end
    end

    context 'when asset is infected' do
      let(:asset) { FactoryGirl.build(:whitehall_asset, state: 'infected') }

      it 'responds with 404 Not Found' do
        get :download, path: path, format: format

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
