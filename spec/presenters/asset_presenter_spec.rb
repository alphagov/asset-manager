require 'rails_helper'

RSpec.describe AssetPresenter do
  subject(:presenter) { described_class.new(asset, view_context) }

  let(:asset) { FactoryBot.build(:asset) }
  let(:view_context) { instance_double(ActionView::Base) }

  context '#as_json' do
    let(:options) { {} }
    let(:json) { presenter.as_json(options) }
    let(:asset_url) { 'asset-url' }
    let(:public_url_path) { '/public-url-path' }

    before do
      allow(view_context).to receive(:asset_url).with(asset.id).and_return(asset_url)
      allow(asset).to receive(:public_url_path).and_return(public_url_path)
    end

    context 'when no status is supplied' do
      let(:options) { { status: nil } }

      it 'returns hash including default response status' do
        expect(json).to include(_response_info: { status: 'ok' })
      end
    end

    context 'when status is supplied' do
      let(:options) { { status: 'not_found' } }

      it 'returns hash including response status' do
        expect(json).to include(_response_info: { status: 'not_found' })
      end
    end

    it 'returns hash including asset URL as API identifier' do
      expect(json).to include(id: 'asset-url')
    end

    it 'returns hash including asset filename as name' do
      expect(json).to include(name: 'asset.png')
    end

    it 'returns hash including asset content type' do
      expect(json).to include(content_type: 'image/png')
    end

    it 'returns hash including public asset URL as file_url' do
      uri = URI.parse(json[:file_url])
      expect("#{uri.scheme}://#{uri.host}").to eq(Plek.new.asset_root)
      expect(uri.path).to eq(public_url_path)
    end

    it 'returns hash including asset state' do
      expect(json).to include(state: 'unscanned')
    end

    context 'when public url path contains non-ascii characters' do
      let(:public_url_path) { '/public-ürl-path' }

      it 'URI encodes the public asset URL' do
        uri = URI.parse(json[:file_url])
        expect(uri.path).to eq(URI.encode(public_url_path))
      end
    end
  end
end
