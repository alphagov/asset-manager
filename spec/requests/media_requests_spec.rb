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

    it "should set the X-Accel-Redirect header" do
      response.should be_success
      id = @asset.id.to_s
      response.headers["X-Accel-Redirect"].should == "/raw/#{id[2..3]}/#{id[4..5]}/#{id}/#{@asset.file.identifier}"
    end

    it "should set the correct content headers" do
      response.headers["Content-Type"].should == "image/png"
      response.headers["Content-Disposition"].should == 'inline; filename="asset.png"'
    end
  end
end
