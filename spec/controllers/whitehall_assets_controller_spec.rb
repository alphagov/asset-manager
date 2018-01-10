require 'rails_helper'

RSpec.describe WhitehallAssetsController, type: :controller do
  render_views # for json responses

  before do
    login_as_stub_user
  end

  describe "POST create" do
    let(:attributes) { FactoryBot.attributes_for(:whitehall_asset, :with_legacy_metadata) }

    context "a valid asset" do
      it "is persisted" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).to be_persisted
      end

      it "stores file on asset" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset).file.current_path).to match(/asset\.png$/)
      end

      it "stores legacy_url_path on asset" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset).legacy_url_path).to eq(attributes[:legacy_url_path])
      end

      it "stores legacy_etag on asset" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset).legacy_etag).to eq(attributes[:legacy_etag])
      end

      it "stores legacy_last_modified on asset" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset).legacy_last_modified).to eq(attributes[:legacy_last_modified])
      end

      it "returns a created status" do
        post :create, params: { asset: attributes }

        expect(response).to have_http_status(:created)
      end

      it "returns JSON response including ID of new asset" do
        post :create, params: { asset: attributes }

        asset = assigns(:asset)
        body = JSON.parse(response.body)
        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
      end

      it "returns JSON response including name of new asset" do
        post :create, params: { asset: attributes }

        body = JSON.parse(response.body)
        expect(body['name']).to eq("asset.png")
      end

      it "returns JSON response including content_type of new asset" do
        post :create, params: { asset: attributes }

        body = JSON.parse(response.body)
        expect(body['content_type']).to eq("image/png")
      end

      it "returns JSON response including URL of new asset" do
        post :create, params: { asset: attributes }

        body = JSON.parse(response.body)
        expected_path = "#{Plek.new.asset_root}#{attributes[:legacy_url_path]}"
        expect(body['file_url']).to eq(expected_path)
      end
    end

    context "an invalid asset" do
      let(:attributes) { { file: nil } }

      it "is not persisted" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).not_to be_persisted
        expect(assigns(:asset).file.current_path).to be_nil
      end

      it "returns an unprocessable entity status" do
        post :create, params: { asset: attributes }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "an asset with the same legacy_url_path as an existing asset" do
      let!(:existing_asset) { FactoryBot.create(:whitehall_asset, legacy_url_path: attributes[:legacy_url_path]) }

      it "marks the existing asset as deleted" do
        post :create, params: { asset: attributes }

        expect(existing_asset.reload).to be_deleted
      end
    end
  end

  describe 'GET show' do
    let(:asset) { FactoryBot.create(:whitehall_asset, legacy_url_path: '/government/uploads/image.png') }
    let(:presenter) { instance_double(AssetPresenter) }

    before do
      allow(AssetPresenter).to receive(:new).with(asset, anything).and_return(presenter)
      allow(presenter).to receive(:as_json).and_return('asset-as-json')
    end

    it 'returns a 200 response' do
      get :show, params: { path: 'government/uploads/image', format: 'png' }

      expect(response).to have_http_status(:ok)
    end

    it 'returns a 404 response if the asset cannot be found' do
      get :show, params: { path: 'government/uploads/non-existent-image', format: 'png' }

      expect(response).to have_http_status(:not_found)
    end

    it 'renders the asset using the AssetPresenter' do
      get :show, params: { path: 'government/uploads/image', format: 'png' }

      expect(response.body).to eq('"asset-as-json"')
    end

    it 'sets the cache expiry to 0 if the asset is unscanned' do
      get :show, params: { path: 'government/uploads/image', format: 'png' }

      expect(response.headers['Cache-Control']).to match('max-age=0')
    end

    it 'sets the cache expiry to 30 minutes if the asset is scanned' do
      asset.scanned_clean!

      get :show, params: { path: 'government/uploads/image', format: 'png' }

      expect(response.headers['Cache-Control']).to match("max-age=#{30.minutes}")
    end

    context "an asset with a legacy_url_path containing URI encoded characters" do
      let(:asset) { FactoryBot.create(:whitehall_asset, legacy_url_path: '/government/uploads/îmage.png') }

      it "renders the asset using the AssetPresenter" do
        get :show, params: { path: URI.encode('government/uploads/îmage'), format: 'png' }

        expect(response.body).to eq('"asset-as-json"')
      end
    end
  end
end
