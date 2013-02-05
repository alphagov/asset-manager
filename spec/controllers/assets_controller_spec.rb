require 'spec_helper'

describe AssetsController do
  render_views # for json responses

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
      it "returns the location of the new asset" do
        post :create, asset: @atts

        asset = assigns(:asset)

        body = JSON.parse(response.body)

        body['asset']['id'].should == "http://test.host/assets/#{asset.id}"
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

end
