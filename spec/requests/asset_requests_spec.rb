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

    it "creates an asset with metadata provided" do

      metadata = {
        title: "My Cat",
        source: "http://catgifs.com/42",
        description: "My cat is lovely",
        creator: "A N Other",
        subject: %w{cat kitty},
        license: "CC BY 3.0",
        spatial: {"lat" => 42.0, "lng" => 23.0},
      }
      
      post "/assets", :asset => { :file => load_fixture_file("asset.png")}.merge(metadata)
      body = JSON.parse(response.body)

      metadata.each_pair do |key, value|
        body[key.to_s].should == value
      end

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
      body["file_url"].should include "#{asset.id}/asset.png"
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
      body["file_url"].should include "#{asset.id}/asset.png"
      body["state"].should == "infected"
    end

    it "retreives details about assets with metadata" do
      asset = FactoryGirl.create(:asset_with_metadata)

      get "/assets/#{asset.id}"
      body = JSON.parse(response.body)

      response.status.should == 200
      body["_response_info"]["status"].should == "ok"

      metadata = {
        title: "My Cat",
        source: "http://catgifs.com/42",
        description: "My cat is lovely",
        creator: "A N Other",
        subject: %w{cat kitty},
        license: "CC BY 3.0",
        spatial: {"lat" => 42.0, "lng" => 23.0},
      }.each_pair do |key, value|
        body[key.to_s].should == value
      end

    end

    it "cannot retrieve details about an asset which does not exist" do
      get "/assets/blah"
      body = JSON.parse(response.body)

      response.status.should == 404
      body["_response_info"]["status"].should == "not found"
    end
  end
end
