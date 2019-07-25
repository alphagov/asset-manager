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

      it "stores access_limited params as access_limited_user_ids on asset" do
        post :create, params: { asset: attributes.merge(access_limited: ['user-id']) }

        expect(assigns(:asset).access_limited_user_ids).to eq(['user-id'])
      end

      it "stores access_limited_user_ids on asset" do
        post :create, params: { asset: attributes.merge(access_limited_user_ids: ['user-id']) }

        expect(assigns(:asset).access_limited_user_ids).to eq(['user-id'])
      end

      it "stores access_limited_organisation_ids on asset" do
        post :create, params: { asset: attributes.merge(access_limited_organisation_ids: ['org-id']) }

        expect(assigns(:asset).access_limited_organisation_ids).to eq(['org-id'])
      end

      it "stores replacement on asset" do
        replacement = FactoryBot.create(:asset)
        replacement_id = replacement.id.to_s
        post :create, params: { asset: { replacement_id: replacement_id } }

        expect(assigns(:asset).replacement).to eq(replacement)
      end

      it 'stores parent_document_url on asset' do
        post :create, params: { asset: attributes.merge(parent_document_url: 'parent-document-url') }

        expect(assigns(:asset).parent_document_url).to eq('parent-document-url')
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

    context "a draft asset" do
      let(:attributes) { FactoryBot.attributes_for(:whitehall_asset, :with_legacy_metadata, draft: true) }

      it "stores draft status on asset" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).to be_draft
      end

      it "returns JSON response including draft status of new asset" do
        post :create, params: { asset: attributes }

        body = JSON.parse(response.body)
        expect(body['draft']).to be_truthy
      end
    end

    context 'an asset with a redirect URL' do
      let(:redirect_url) { 'https://example.com/path/file.ext' }
      let(:attributes) { FactoryBot.attributes_for(:whitehall_asset, redirect_url: redirect_url) }

      it 'returns JSON response including redirect URL of new asset' do
        post :create, params: { asset: attributes }

        body = JSON.parse(response.body)
        expect(body['redirect_url']).to eq(redirect_url)
      end

      context 'and redirect URL is blank' do
        let(:redirect_url) { '' }

        it 'stores redirect URL as nil' do
          post :create, params: { asset: attributes }

          expect(assigns(:asset).redirect_url).to be_nil
        end
      end
    end
  end

  describe 'GET show' do
    let(:legacy_url_path) { '/government/uploads/image.png' }
    let(:asset) { FactoryBot.create(:whitehall_asset, legacy_url_path: legacy_url_path) }
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

    it 'sets the Cache-Control header to no-cache' do
      get :show, params: { path: 'government/uploads/image', format: 'png' }

      expect(response.headers['Cache-Control']).to match('no-cache')
    end

    context 'and legacy_url_path has no format' do
      let(:legacy_url_path) { '/government/uploads/file' }

      it 'returns a 200 response' do
        get :show, params: { path: 'government/uploads/file' }

        expect(response).to have_http_status(:ok)
      end
    end

    context 'when the asset has been deleted' do
      before do
        asset.destroy
      end

      it 'returns a 200 response' do
        get :show, params: { path: 'government/uploads/image', format: 'png' }

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
