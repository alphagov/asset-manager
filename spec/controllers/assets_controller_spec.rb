require 'rails_helper'

RSpec.describe AssetsController, type: :controller do
  render_views # for json responses

  before do
    login_as_stub_user
  end

  describe "POST create" do
    context "a valid asset" do
      let(:attributes) { { file: load_fixture_file("asset.png") } }

      it "is persisted" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).to be_persisted
        expect(assigns(:asset).file.path).to match(/asset\.png$/)
      end

      it "returns a created status" do
        post :create, params: { asset: attributes }

        expect(response).to have_http_status(:created)
      end

      it "returns the location and details of the new asset" do
        post :create, params: { asset: attributes }

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
        expect(body['name']).to eq("asset.png")
        expect(body['content_type']).to eq("image/png")
        expect(body['draft']).to be_falsey
      end
    end

    context "an invalid asset" do
      let(:attributes) { { file: nil } }

      it "is not persisted" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).not_to be_persisted
        expect(assigns(:asset).file.path).to be_nil
      end

      it "returns an unprocessable entity status" do
        post :create, params: { asset: attributes }

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "a draft asset" do
      let(:attributes) { { draft: true, file: load_fixture_file("asset.png") } }

      it "is persisted" do
        post :create, params: { asset: attributes }

        expect(assigns(:asset)).to be_draft
      end

      it "returns the draft status of the new asset" do
        post :create, params: { asset: attributes }

        body = JSON.parse(response.body)

        expect(body['draft']).to be_truthy
      end
    end

    context 'an asset with a redirect URL' do
      let(:redirect_url) { 'https://example.com/path/file.ext' }
      let(:attributes) { { redirect_url: redirect_url, file: load_fixture_file("asset.png") } }

      it 'stores redirect URL' do
        post :create, params: { asset: attributes }

        expect(assigns(:asset).redirect_url).to eq(redirect_url)
      end
    end
  end

  describe "PUT update" do
    context "a valid asset" do
      let(:attributes) { { file: load_fixture_file("asset2.jpg") } }
      let(:asset) { FactoryBot.create(:asset) }

      it "updates attributes" do
        put :update, params: { id: asset.id, asset: attributes }

        expect(assigns(:asset)).to be_persisted
        expect(assigns(:asset).file.path).to match(/asset2\.jpg$/)
      end

      it "returns a success status" do
        put :update, params: { id: asset.id, asset: attributes }

        expect(response).to have_http_status(:success)
      end

      it "returns the location and details of the new asset" do
        put :update, params: { id: asset.id, asset: attributes }

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
        expect(body['name']).to eq("asset2.jpg")
        expect(body['content_type']).to eq("image/jpeg")
        expect(body['draft']).to be_falsey
      end

      context "a draft asset" do
        let(:attributes) { { draft: true, file: load_fixture_file("asset2.jpg") } }
        let(:asset) { FactoryBot.create(:asset) }

        it "updates attributes" do
          put :update, params: { id: asset.id, asset: attributes }

          expect(assigns(:asset)).to be_draft
        end

        it "returns the draft status of the updated asset" do
          put :update, params: { id: asset.id, asset: attributes }

          body = JSON.parse(response.body)

          expect(body['draft']).to be_truthy
        end
      end
    end
  end

  describe "DELETE destroy" do
    context "a valid asset" do
      let(:asset) { FactoryBot.create(:asset) }

      it "deletes the asset" do
        delete :destroy, params: { id: asset.id }

        expect(Asset.where(id: asset.id).first).to be_nil
      end

      it "returns a success status" do
        delete :destroy, params: { id: asset.id }

        expect(response).to have_http_status(:success)
      end
    end

    context "an asset that doesn't exist" do
      it "responds with not found status" do
        delete :destroy, params: { id: "12345" }
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when Asset#destroy fails" do
      let(:asset) { FactoryBot.create(:asset) }
      let(:errors) { ActiveModel::Errors.new(asset) }

      before do
        errors.add(:base, "Something went wrong")
        allow_any_instance_of(Asset).to receive(:destroy).and_return(false)
        allow_any_instance_of(Asset).to receive(:errors).and_return(errors)
        delete :destroy, params: { id: asset.id }
      end

      it "responds with unprocessable entity status" do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns the asset errors" do
        expect(response.body).to match(/Something went wrong/)
      end
    end
  end

  describe "GET show" do
    context "an asset which exists" do
      let(:asset) { FactoryBot.create(:asset) }

      it "is a successful request" do
        get :show, params: { id: asset.id }

        expect(response).to be_success
      end

      it "assigns the asset to the template" do
        get :show, params: { id: asset.id }

        expect(assigns(:asset)).to be_a(Asset)
        expect(assigns(:asset).id).to eq(asset.id)
      end

      it "returns the draft status of the asset" do
        get :show, params: { id: asset.id }

        body = JSON.parse(response.body)

        expect(body['draft']).to be_falsey
      end

      it "sets the Cache-Control header max-age to 0" do
        get :show, params: { id: asset.id }

        expect(response.headers["Cache-Control"]).to eq("max-age=0, public")
      end
    end

    context "an asset which does not exist" do
      it "returns a not found status" do
        get :show, params: { id: "some-gif-or-other" }

        expect(response).to have_http_status(:not_found)
      end

      it "returns a not found message" do
        get :show, params: { id: "some-gif-or-other" }

        body = JSON.parse(response.body)
        expect(body['_response_info']['status']).to eq("not found")
      end
    end

    describe "POST restore" do
      let(:asset) { FactoryBot.create(:asset, deleted_at: 10.minutes.ago) }

      context "an asset which has been soft deleted" do
        before do
          post :restore, params: { id: asset.id }
        end

        it "is a successful request" do
          expect(response).to be_success
        end

        it "assigns the asset" do
          restored_asset = assigns(:asset)
          expect(restored_asset).to be
          expect(restored_asset.deleted_at).to be_nil
        end
      end

      context "when restoring fails" do
        let(:errors) { ActiveModel::Errors.new(asset) }

        before do
          errors.add(:base, "Something went wrong")
          allow_any_instance_of(Asset).to receive(:restore).and_return(false)
          allow_any_instance_of(Asset).to receive(:errors).and_return(errors)
          post :restore, params: { id: asset.id }
        end

        it "responds with unprocessable entity status" do
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it "responds with an error message" do
          expect(response.body).to match(/Something went wrong/)
        end
      end
    end
  end
end
