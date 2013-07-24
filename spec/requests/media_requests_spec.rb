require "spec_helper"

describe "Media requests" do
  describe "requesting an asset that doesn't exist" do
    it "should respond with file not found" do
      get "/media/34/test.jpg"
      response.status.should == 404
    end
  end

  describe "request an asset that does exist" do
    before(:each) do
      @asset = FactoryGirl.create(:clean_asset)

      get "/media/#{@asset.id}/asset.png", nil, {
        "HTTP_X_SENDFILE_TYPE" => "X-Accel-Redirect",
        "HTTP_X_ACCEL_MAPPING" => "#{Rails.root}/tmp/test_uploads/assets/=/raw/"
      }
    end

    it "should redirect" do
      response.should be_redirect
    end

    it "should redirect to the correct location" do
      response.headers["Location"].should == @asset.file.to_s
    end
  end
end
