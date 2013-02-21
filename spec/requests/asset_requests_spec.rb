require "spec_helper"

describe "Asset requests" do
  before(:each) do
    login_as_stub_user
  end

  describe "uploading an asset" do
    it "creates an asset with the file provided" do
      post "/assets", :asset => { :file => load_fixture_file("asset.png") }
      body = JSON.parse(response.body)

      response.status.should == 201
      body["_response_info"]["status"].should == "created"

      body["id"].should =~ %r{http://www.example.com/assets/[a-z0-9]+}
      body["name"].should == "asset.png"
      body["content_type"].should == "image/png"
    end

    it "cannot create an asset without a file" do
      post "/assets", :asset => { :file => nil }
      body = JSON.parse(response.body)

      response.status.should == 422
      body["_response_info"]["status"].should == ["File can't be blank"]
    end
  end

  describe "retrieving an asset" do
    it "retreives details about an existing asset" do
      asset = FactoryGirl.create(:asset)

      get "/assets/#{asset.id}"
      body = JSON.parse(response.body)

      response.status.should == 200
      body["_response_info"]["status"].should == "ok"

      body["id"].should == "http://www.example.com/assets/#{asset.id}"
      body["name"].should == "asset.png"
      body["content_type"].should == "image/png"
      body["file_url"].should == "https://static.test.gov.uk/media/#{asset.id}/asset.png"
    end

    it "cannot retrieve details about an asset which does not exist" do
      get "/assets/blah"
      body = JSON.parse(response.body)

      response.status.should == 404
      body["_response_info"]["status"].should == "not found"
    end
  end
end
