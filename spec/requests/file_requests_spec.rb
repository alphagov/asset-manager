require "spec_helper"

describe "File requests" do
  before(:each) do
    login_as_stub_user
  end

  describe "requesting an asset that doesn't exist" do
    it "should respond with file not found" do
      get "/#{ASSET_PREFIX}/files/34/test.jpg"
      response.status.should == 404
    end
  end

  describe "request an asset that does exist" do
    before(:each) do
      @asset = FactoryGirl.create(:asset)
      get "/#{ASSET_PREFIX}/files/#{@asset.id}/asset.png"
    end

    it "should set the X-Sendfile header" do
      response.should be_success
      response.headers["X-Sendfile"].should == @asset.file.path
    end
  end
end
