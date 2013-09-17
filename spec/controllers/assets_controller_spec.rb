require 'spec_helper'

describe AssetsController do
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

        assigns(:asset).should be_persisted
        assigns(:asset).file.current_path.should =~ /asset\.png$/
      end
      it "returns a created status" do
        post :create, asset: @atts

        response.status.should == 201
      end
      it "returns the location and details of the new asset" do
        post :create, asset: @atts

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        body['id'].should == "http://test.host/assets/#{asset.id}"
        body['name'].should == "asset.png"
        body['content_type'].should == "image/png"
      end
    end

    context "an invalid asset" do
      before do
        @atts = { :file => nil }
      end

      it "is not persisted" do
        post :create, asset: @atts

        assigns(:asset).should_not be_persisted
        assigns(:asset).file.current_path.should be_nil
      end

      it "returns an unprocessable status" do
        post :create, asset: @atts

        response.status.should == 422
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

        response.should be_success
      end

      it "assigns the asset to the template" do
        get :show, id: @asset.id

        assigns(:asset).should be_a(Asset)
        assigns(:asset).id.should == @asset.id
      end
    end

    context "an asset which does not exist" do
      it "returns a not found status" do
        get :show, id: "some-gif-or-other"

        response.status.should == 404
      end

      it "returns a not found message" do
        get :show, id: "some-gif-or-other"

        body = JSON.parse(response.body)
        body['_response_info']['status'].should == "not found"
      end
    end

    describe "cache headers" do
      it "sets the cache-control headers to 0 for an unscanned asset" do
        asset = FactoryGirl.create(:asset, :state => 'unscanned')
        get :show, id: asset.id

        response.headers["Cache-Control"].should == "max-age=0, public"
      end

      it "sets the cache-control headers to 30 minutes for a clean asset" do
        asset = FactoryGirl.create(:asset)
        asset.scanned_clean!
        get :show, id: asset.id

        response.headers["Cache-Control"].should == "max-age=1800, public"
      end

      it "sets the cache-control headers to 30 minutes for an infected asset" do
        asset = FactoryGirl.create(:asset)
        asset.scanned_infected!
        get :show, id: asset.id

        response.headers["Cache-Control"].should == "max-age=1800, public"
      end
    end
  end

end
