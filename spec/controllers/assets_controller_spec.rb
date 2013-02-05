require 'spec_helper'

describe AssetsController do
  render_views # for json responses

  describe "POST create" do
    context "a valid asset" do
      before do
        @atts = { :file => load_fixture_file("asset.png") }
      end

      it "is uploaded" do
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
      it "is not uploaded"
      it "returns an unprocessable status"
    end
  end

end
