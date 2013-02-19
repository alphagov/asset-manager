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

      context "Cache headers" do
        it "should have a max-age of 12 hours" do
          response.headers["Cache-Control"].should include "max-age=86400"
        end

        it "should have a public directive" do
          response.headers["Cache-Control"].should include "public"
        end

        it "should have a stale-if-error of 1 day" do
          response.headers["Cache-Control"].should include "stale-if-error=86400"
        end

        it "should have a stale-while-revalidate of 1 day" do
          response.headers["Cache-Control"].should include "stale-while-revalidate=86400"
        end
      end
    end
  end
end
