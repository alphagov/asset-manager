require 'rails_helper'

RSpec.describe 'Whitehall media requests', type: :request do
  describe 'request for an asset which does not exist' do
    it 'responds with 404 Not Found status' do
      get '/government/uploads/asset.png'

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'request for an unscanned image asset' do
    let(:path) { '/government/uploads/asset.png' }

    before do
      FactoryGirl.create(
        :whitehall_asset,
        file: load_fixture_file('asset.png'),
        legacy_url_path: path
      )

      get path
    end

    it 'redirects to placeholder image' do
      expect(response).to redirect_to('/images/thumbnail-placeholder.png')
    end

    it 'sets the Cache-Control response header to 1 minute' do
      expect(response.headers['Cache-Control']).to eq('max-age=60, public')
    end
  end

  describe 'request for an unscanned non-image asset' do
    let(:path) { '/government/uploads/lorem.txt' }

    before do
      FactoryGirl.create(
        :whitehall_asset,
        file: load_fixture_file('lorem.txt'),
        legacy_url_path: path
      )

      get path
    end

    it 'redirects to government placeholder page' do
      expect(response).to redirect_to('/government/placeholder')
    end

    it 'sets the Cache-Control response header to 1 minute' do
      expect(response.headers['Cache-Control']).to eq('max-age=60, public')
    end
  end

  describe 'request for a clean asset' do
    let(:path) { '/government/uploads/asset.png' }
    let!(:asset) { FactoryGirl.create(:clean_whitehall_asset, legacy_url_path: path) }

    before do
      get path, nil,
        'HTTP_X_SENDFILE_TYPE' => 'X-Accel-Redirect',
        'HTTP_X_ACCEL_MAPPING' => "#{Rails.root}/tmp/test_uploads/assets/=/raw/"
    end

    it 'responds with 200 OK' do
      expect(response).to have_http_status(:ok)
    end

    it 'sets the X-Accel-Redirect response header' do
      id = asset.id.to_s
      expected_path = "/raw/#{id[2..3]}/#{id[4..5]}/#{id}/#{asset.file.identifier}"
      expect(response.headers['X-Accel-Redirect']).to eq(expected_path)
    end

    it 'sets the Content-Type response header' do
      expect(response.headers['Content-Type']).to eq('image/png')
    end

    it 'sets the Content-Disposition response header' do
      expect(response.headers['Content-Disposition']).to eq('inline; filename="asset.png"')
    end

    it 'sets the Cache-Control response header to 4 hours' do
      expect(response.headers['Cache-Control']).to eq('max-age=14400, public')
    end
  end
end
