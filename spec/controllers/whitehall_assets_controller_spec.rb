require 'rails_helper'

RSpec.describe WhitehallAssetsController, type: :controller do
  render_views # for json responses

  before do
    login_as_stub_user
  end

  describe "POST create" do
    context "a valid asset" do
      let(:legacy_url_path) { "/government/uploads/asset.png" }
      let(:attributes) {
        {
          file: load_fixture_file("asset.png"),
          legacy_url_path: legacy_url_path
        }
      }

      it "is persisted" do
        post :create, asset: attributes

        expect(assigns(:asset)).to be_persisted
        expect(assigns(:asset).file.current_path).to match(/asset\.png$/)
      end

      it "returns a created status" do
        post :create, asset: attributes

        expect(response).to have_http_status(:created)
      end

      it "returns JSON response including ID of new asset" do
        post :create, asset: attributes

        asset = assigns(:asset)
        body = JSON.parse(response.body)
        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
      end

      it "returns JSON response including name of new asset" do
        post :create, asset: attributes

        body = JSON.parse(response.body)
        expect(body['name']).to eq("asset.png")
      end

      it "returns JSON response including content_type of new asset" do
        post :create, asset: attributes

        body = JSON.parse(response.body)
        expect(body['content_type']).to eq("image/png")
      end

      it "returns JSON response including URL of new asset" do
        post :create, asset: attributes

        body = JSON.parse(response.body)
        expect(body['file_url']).to eq("#{Plek.new.asset_root}#{legacy_url_path}")
      end
    end

    context "an invalid asset" do
      let(:attributes) { { file: nil } }

      it "is not persisted" do
        post :create, asset: attributes

        expect(assigns(:asset)).not_to be_persisted
        expect(assigns(:asset).file.current_path).to be_nil
      end

      it "returns an unprocessable entity status" do
        post :create, asset: attributes

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end
end
