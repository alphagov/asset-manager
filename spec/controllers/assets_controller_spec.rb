require 'rails_helper'

RSpec.describe AssetsController, type: :controller do
  render_views # for json responses

  before(:each) do
    login_as_stub_user
  end

  describe "POST create" do
    context "a valid asset" do
      before do
        @atts = { :file => load_fixture_file("asset.png") }
      end

      it "is persisted" do
        post :create, asset: @atts

        expect(assigns(:asset)).to be_persisted
        expect(assigns(:asset).file.current_path).to match(/asset\.png$/)
      end
      it "returns a created status" do
        post :create, asset: @atts

        expect(response.status).to eq(201)
      end
      it "returns the location and details of the new asset" do
        post :create, asset: @atts

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
        expect(body['name']).to eq("asset.png")
        expect(body['content_type']).to eq("image/png")
      end
    end

    context "an invalid asset" do
      before do
        @atts = { :file => nil }
      end

      it "is not persisted" do
        post :create, asset: @atts

        expect(assigns(:asset)).not_to be_persisted
        expect(assigns(:asset).file.current_path).to be_nil
      end

      it "returns an unprocessable status" do
        post :create, asset: @atts

        expect(response.status).to eq(422)
      end
    end
  end

  describe "PUT update" do
    context "a valid asset" do
      before do
        @asset = FactoryGirl.create(:asset)
        @atts = {
          :file => load_fixture_file("asset2.jpg"),
        }
      end

      it "updates attributes" do
        put :update, id: @asset.id, asset: @atts

        expect(assigns(:asset)).to be_persisted
        expect(assigns(:asset).file.current_path).to match(/asset2\.jpg$/)
      end

      it "returns a success status" do
        put :update, id: @asset.id, asset: @atts

        expect(response.status).to eq(200)
      end

      it "returns the location and details of the new asset" do
        put :update, id: @asset.id, asset: @atts

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        expect(body['id']).to eq("http://test.host/assets/#{asset.id}")
        expect(body['name']).to eq("asset2.jpg")
        expect(body['content_type']).to eq("image/jpeg")
      end
    end

    context "an invalid asset" do
      before do
        @atts = { :file => nil }
      end

      it "is not persisted" do
        post :create, asset: @atts

        expect(assigns(:asset)).not_to be_persisted
        expect(assigns(:asset).file.current_path).to be_nil
      end

      it "returns an unprocessable status" do
        post :create, asset: @atts

        expect(response.status).to eq(422)
      end
    end
  end

  describe "GET show" do
    context "an asset which exists" do
      before do
        @asset = FactoryGirl.create(:asset)
      end

      it "is a successful request" do
        get :show, id: @asset.id

        expect(response).to be_success
      end

      it "assigns the asset to the template" do
        get :show, id: @asset.id

        expect(assigns(:asset)).to be_a(Asset)
        expect(assigns(:asset).id).to eq(@asset.id)
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

    describe "cache headers" do
      it "sets the cache-control headers to 0 for an unscanned asset" do
        asset = FactoryGirl.create(:asset, :state => 'unscanned')
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
