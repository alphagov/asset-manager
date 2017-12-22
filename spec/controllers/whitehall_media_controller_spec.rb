require "rails_helper"

RSpec.describe WhitehallMediaController, type: :controller do
  shared_examples 'handles valid asset request' do
    it "proxies asset to S3 via Nginx" do
      expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

      get :download, params: { path: path, format: format }
    end

    context 'and legacy_url_path has no format' do
      let(:legacy_url_path) { "/government/uploads/#{path}" }

      it "proxies asset to S3 via Nginx" do
        expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

        get :download, params: { path: path, format: nil }
      end
    end
  end

  shared_examples 'redirects to placeholders' do
    before do
      allow(asset).to receive(:image?).and_return(image)
    end

    context 'and asset is image' do
      let(:image) { true }

      it 'redirects to thumbnail-placeholder image' do
        get :download, params: { path: path, format: format }

        expect(controller).to redirect_to(described_class.helpers.image_path('thumbnail-placeholder.png'))
      end
    end

    context 'and asset is not an image' do
      let(:image) { false }

      it 'redirects to government placeholder page' do
        get :download, params: { path: path, format: format }

        expect(controller).to redirect_to('/government/placeholder')
      end
    end
  end

  describe '#download' do
    let(:path) { 'path/to/asset' }
    let(:format) { 'png' }
    let(:legacy_url_path) { "/government/uploads/#{path}.#{format}" }
    let(:asset) { FactoryBot.build(:whitehall_asset, legacy_url_path: legacy_url_path, state: state) }

    before do
      allow(WhitehallAsset).to receive(:find_by).with(legacy_url_path: legacy_url_path).and_return(asset)
    end

    context 'when asset is clean' do
      let(:state) { 'clean' }

      include_examples 'handles valid asset request'
    end

    context 'when asset is uploaded' do
      let(:state) { 'uploaded' }

      include_examples 'handles valid asset request'
    end

    context 'when asset is unscanned' do
      let(:state) { 'unscanned' }

      include_examples 'redirects to placeholders'
    end

    context 'when asset is infected' do
      let(:state) { 'infected' }

      it 'responds with 404 Not Found' do
        get :download, params: { path: path, format: format }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
