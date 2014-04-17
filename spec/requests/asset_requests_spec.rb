require "spec_helper"

describe "Asset requests" do
  before(:each) do
    login_as_stub_user
    Plek.any_instance.stub(:asset_root).and_return("http://assets.digital.cabinet-office.gov.uk")
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
      body["state"].should == "unscanned"
    end

    it "cannot create an asset without a file" do
      post "/assets", :asset => { :file => nil }
      body = JSON.parse(response.body)

      response.status.should == 422
      body["_response_info"]["status"].should == ["File can't be blank"]
    end
  end

  describe "updating an asset" do
    let(:asset_id) {
      post "/assets", :asset => { :file => load_fixture_file("asset.png") }
      body = JSON.parse(response.body)
      body.fetch("id").split("/").last
    }

    it "updates an asset with the file provided" do
      put "/assets/#{asset_id}", :asset => { :file => load_fixture_file("asset2.jpg") }
      body = JSON.parse(response.body)

      response.status.should == 200
      body["_response_info"]["status"].should == "success"

      body["id"].should end_with(asset_id)
      body["name"].should == "asset2.jpg"
      body["content_type"].should == "image/jpeg"
      body["state"].should == "unscanned"
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
      asset = FactoryGirl.create(:clean_asset)

      get "/assets/#{asset.id}"
      body = JSON.parse(response.body)

      response.status.should == 200
      body["_response_info"]["status"].should == "ok"

      body["id"].should == "http://www.example.com/assets/#{asset.id}"
      body["name"].should == "asset.png"
      body["content_type"].should == "image/png"
      body["file_url"].should == "http://assets.digital.cabinet-office.gov.uk/media/#{asset.id}/asset.png"
      body["state"].should == "clean"
    end

    it "returns details about an infected asset" do
      asset = FactoryGirl.create(:infected_asset)

      get "/assets/#{asset.id}"
      body = JSON.parse(response.body)

      response.status.should == 200
      body["_response_info"]["status"].should == "ok"

      body["id"].should == "http://www.example.com/assets/#{asset.id}"
      body["name"].should == "asset.png"
      body["content_type"].should == "image/png"
      body["file_url"].should == "http://assets.digital.cabinet-office.gov.uk/media/#{asset.id}/asset.png"
      body["state"].should == "infected"
    end

    it "cannot retrieve details about an asset which does not exist" do
      get "/assets/blah"
      body = JSON.parse(response.body)

      response.status.should == 404
      body["_response_info"]["status"].should == "not found"
    end
  end
end
