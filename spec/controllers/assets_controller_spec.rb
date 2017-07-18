require 'rails_helper'

RSpec.describe AssetsController, type: :controller do
  render_views # for json responses

  before do
    login_as_stub_user
  end

  describe "POST create" do
    context "a valid asset" do
      let(:atts) { { file: load_fixture_file("asset.png") } }

      it "is persisted" do
        post :create, asset: atts

        expect(assigns(:asset)).to be_persisted
        expect(assigns(:asset).file.current_path).to match(/asset\.png$/)
      end
      it "returns a created status" do
        post :create, asset: atts

        expect(response.status).to eq(201)
      end
      it "returns the location and details of the new asset" do
        post :create, asset: atts

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
        expect(body['name']).to eq("asset.png")
        expect(body['content_type']).to eq("image/png")
      end
    end

    context "an invalid asset" do
      let(:atts) { { file: nil } }

      it "is not persisted" do
        post :create, asset: atts

        expect(assigns(:asset)).not_to be_persisted
        expect(assigns(:asset).file.current_path).to be_nil
      end

      it "returns an unprocessable status" do
        post :create, asset: atts

        expect(response.status).to eq(422)
      end
    end
  end

  describe "PUT update" do
    context "a valid asset" do
      let(:atts) { { file: load_fixture_file("asset2.jpg") } }
      let(:asset) { FactoryGirl.create(:asset) }

      it "updates attributes" do
        put :update, id: asset.id, asset: atts

        expect(assigns(:asset)).to be_persisted
        expect(assigns(:asset).file.current_path).to match(/asset2\.jpg$/)
      end

      it "returns a success status" do
        put :update, id: asset.id, asset: atts

        expect(response.status).to eq(200)
      end

      it "returns the location and details of the new asset" do
        put :update, id: asset.id, asset: atts

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
        expect(body['name']).to eq("asset2.jpg")
        expect(body['content_type']).to eq("image/jpeg")
      end
    end

    context "an invalid asset" do
      let(:atts) { { file: nil } }

      it "is not persisted" do
        post :create, asset: atts

        expect(assigns(:asset)).not_to be_persisted
        expect(assigns(:asset).file.current_path).to be_nil
      end

      it "returns an unprocessable status" do
        post :create, asset: atts

        expect(response.status).to eq(422)
      end
    end
  end

  describe "DELETE destroy" do
    context "a valid asset" do
      let(:asset) { FactoryGirl.create(:asset) }

      it "deletes the asset" do
        delete :destroy, id: asset.id

        expect((get :show, id: asset.id).status).to eq(404)
      end

      it "returns a success status" do
        delete :destroy, id: asset.id

        expect(response.status).to eq(200)
      end
    end

    context "an asset that doesn't exist" do
      it "responds with 404" do
        delete :destroy, id: "12345"
        expect(response.status).to eq(404)
      end
    end

    context "when Asset#destroy fails" do
      let(:asset) { FactoryGirl.create(:asset) }
      let(:errors) { ActiveModel::Errors.new(asset) }

      before do
        errors.add(:base, "Something went wrong")
        allow_any_instance_of(Asset).to receive(:destroy).and_return(false)
        allow_any_instance_of(Asset).to receive(:errors).and_return(errors)
        delete :destroy, id: asset.id
      end

      it "responds with 422" do
        expect(response.status).to eq(422)
      end

      it "returns the asset errors" do
        expect(response.body).to match(/Something went wrong/)
      end
    end
  end

  describe "GET show" do
    context "an asset which exists" do
      let(:asset) { FactoryGirl.create(:asset) }

      it "is a successful request" do
        get :show, id: asset.id

        expect(response).to be_success
      end

      it "assigns the asset to the template" do
        get :show, id: asset.id

        expect(assigns(:asset)).to be_a(Asset)
        expect(assigns(:asset).id).to eq(asset.id)
      end
    end

    context "an asset which does not exist" do
      it "returns a not found status" do
        get :show, id: "some-gif-or-other"

        expect(response.status).to eq(404)
      end

      it "returns a not found message" do
        get :show, id: "some-gif-or-other"

        body = JSON.parse(response.body)
        expect(body['_response_info']['status']).to eq("not found")
      end
    end

    describe "POST restore" do
      let(:asset) { FactoryGirl.create(:asset, deleted_at: 10.minutes.ago) }

      context "an asset which has been soft deleted" do
        before do
          post :restore, id: asset.id
        end

        it "is a successful request" do
          expect(response).to be_successful
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
          post :restore, id: asset.id
        end

        it "responds with 422" do
          expect(response.status).to be(422)
        end

        it "responds with an error message" do
          expect(response.body).to match(/Something went wrong/)
        end
      end
    end

    describe "cache headers" do
      it "sets the cache-control headers to 0 for an unscanned asset" do
        asset = FactoryGirl.create(:asset, state: 'unscanned')
        get :show, id: asset.id

        expect(response.headers["Cache-Control"]).to eq("max-age=0, public")
      end

      it "sets the cache-control headers to 30 minutes for a clean asset" do
        asset = FactoryGirl.create(:asset)
        asset.scanned_clean!
        get :show, id: asset.id

        expect(response.headers["Cache-Control"]).to eq("max-age=1800, public")
      end

      it "sets the cache-control headers to 30 minutes for an infected asset" do
        asset = FactoryGirl.create(:asset)
        asset.scanned_infected!
        get :show, id: asset.id

        expect(response.headers["Cache-Control"]).to eq("max-age=1800, public")
      end
    end
  end
end
