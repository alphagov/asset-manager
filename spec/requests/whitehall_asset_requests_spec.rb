require 'rails_helper'

RSpec.describe 'Asset requests', type: :request do
  before do
    login_as_stub_user
  end

  describe 'request to upload an asset' do
    let(:file) { load_fixture_file('asset.png') }
    let(:legacy_url_path) { '/government/uploads/path/to/asset.png' }

    before do
      post '/whitehall_assets', asset: {
        file: file,
        legacy_url_path: legacy_url_path
      }
    end

    it 'responds with 201 Created' do
      expect(response).to have_http_status(:created)
    end

    it 'responds with JSON containing created status' do
      body = JSON.parse(response.body)
      expect(body['_response_info']['status']).to eq('created')
    end

    it 'responds with JSON containing new asset ID' do
      body = JSON.parse(response.body)
      expect(body['id']).to match(%r{http://www.example.com/assets/[a-z0-9]+})
    end

    it 'responds with JSON containing new asset name' do
      body = JSON.parse(response.body)
      expect(body['name']).to eq('asset.png')
    end

    it 'responds with JSON containing new asset content_type' do
      body = JSON.parse(response.body)
      expect(body['content_type']).to eq('image/png')
    end

    it 'responds with JSON containing new asset state' do
      body = JSON.parse(response.body)
      expect(body['state']).to eq('unscanned')
    end

    it 'responds with JSON containing new asset URL' do
      body = JSON.parse(response.body)
      expect(body['file_url']).to eq("#{Plek.new.asset_root}#{legacy_url_path}")
    end

    context 'when file is not supplied' do
      let(:file) { nil }

      it 'cannot create an asset' do
        body = JSON.parse(response.body)

        expect(response).to have_http_status(:unprocessable_entity)
        expected_message = "File can't be blank"
        expect(body['_response_info']['status']).to include(expected_message)
      end
    end

    context 'when legacy_url_path is not valid' do
      let(:legacy_url_path) { '/path/not/under/government/uploads/asset.png' }

      it 'cannot create an asset' do
        body = JSON.parse(response.body)

        expect(response).to have_http_status(:unprocessable_entity)
        expected_message = 'Legacy url path must start with /government/uploads'
        expect(body['_response_info']['status']).to include(expected_message)
      end
    end
  end
end
