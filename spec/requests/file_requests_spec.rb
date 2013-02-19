require "spec_helper"

describe "File requests" do
  before(:each) do
    login_as_stub_user
  end

  describe "requesting an asset that doesn't exist" do
    it "should respond with file not found" do
      get "/files/34/test.jpg"
      response.status.should == 404
    end
  end

  describe "request an asset that does exist" do
    it "should return the file we requested" do
      asset = FactoryGirl.create(:asset)

      get "/files/#{asset.id}/asset.png"

      response.should be_success
      Digest::MD5.hexdigest(body).should == Digest::MD5.hexdigest(File.open(asset.file.path).read)
    end
  end
end
