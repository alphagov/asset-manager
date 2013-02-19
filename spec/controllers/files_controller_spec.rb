require "spec_helper"

describe FilesController do
  before(:each) do
    login_as_stub_user
  end

  describe "GET files" do
    describe "HTTP headers" do
      before(:each) do
        @asset = FactoryGirl.create(:asset)
        get :download, :id => @asset.id, :filename => @asset.file.identifier
      end

      it "should load successfully" do
        response.should be_success
      end

      it "should have the correct content type" do
        response.headers["Content-Type"].should == "image/png"
      end

      it "should set the X-Sendfile header" do
        response.headers["X-Sendfile"] == @asset.file.identifier
      end
    end
  end
end
