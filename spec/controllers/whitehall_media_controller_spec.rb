require "rails_helper"

RSpec.describe WhitehallMediaController, type: :controller do
  describe '#download' do
    let(:path) { 'path/to/asset' }
    let(:format) { 'png' }
    let(:legacy_url_path) { "/government/uploads/#{path}.#{format}" }

    before do
      allow(WhitehallAsset).to receive(:find_by).with(legacy_url_path: legacy_url_path).and_return(asset)
    end

    context 'when asset is clean' do
      let(:asset) { FactoryBot.build(:whitehall_asset, legacy_url_path: legacy_url_path, state: 'clean') }

      context "when true" do
        it "proxies asset to S3 via Nginx" do
          expect(controller).to receive(:proxy_to_s3_via_nginx).with(asset)

          get :download, params: { path: path, format: format }
        end
      end
    end

    context 'when asset is unscanned image' do
      let(:asset) { FactoryBot.build(:whitehall_asset, state: 'unscanned') }

      before do
        allow(asset).to receive(:image?).and_return(true)
      end

      it 'redirects to thumbnail-placeholder image' do
        get :download, params: { path: path, format: format }

        expect(controller).to redirect_to(described_class.helpers.image_path('thumbnail-placeholder.png'))
      end
    end

    context 'when asset is unscanned non-image' do
      let(:asset) { FactoryBot.build(:whitehall_asset, state: 'unscanned') }

      before do
        allow(asset).to receive(:image?).and_return(false)
      end

      it 'redirects to government placeholder page' do
        get :download, params: { path: path, format: format }

        expect(controller).to redirect_to('/government/placeholder')
      end
    end

    context 'when asset is infected' do
      let(:asset) { FactoryBot.build(:whitehall_asset, state: 'infected') }

      it 'responds with 404 Not Found' do
        get :download, params: { path: path, format: format }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
