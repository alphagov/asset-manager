require "spec_helper"

describe MediaController do

  describe "GET 'download'" do
    before(:each) do
      controller.stub(requested_via_private_vhost?: false)
    end

    context "with a valid clean file" do
      before :each do
        @asset = FactoryGirl.create(:clean_asset)
      end

      def do_get
        get :download, :id => @asset.id.to_s, :filename => @asset.file.file.identifier
      end

      it "should be successful" do
        do_get
        response.should be_success
      end

      it "should send the file using send_file" do
        controller.should_receive(:send_file).with(@asset.file.path, :disposition => "inline")
        controller.stub(:render) # prevent template_not_found errors because we intercepted send_file

        do_get
      end

      it "should have the correct content type" do
        do_get
        response.headers["Content-Type"].should == "image/png"
      end

      it "should set the cache-control headers to 24 hours" do
        do_get

        response.headers["Cache-Control"].should == "max-age=86400, public"
      end
    end

    context "with an unscanned file" do
      before :each do
        @asset = FactoryGirl.create(:asset)
      end

      it "should return a 404" do
        get :download, :id => @asset.id.to_s, :filename => @asset.file.file.identifier
        response.code.to_i.should == 404
      end
    end

    context "with an infected file" do
      before :each do
        @asset = FactoryGirl.create(:infected_asset)
      end

      it "should return a 404" do
        get :download, :id => @asset.id.to_s, :filename => @asset.file.file.identifier
        response.code.to_i.should == 404
      end
    end

    context "with an invalid url" do
      it "should 404 for a non-existent ID" do
        get :download, :id => "1234556678895332452345", :filename => "something.jpg"
        response.code.to_i.should == 404
      end

      it "should 404 for a valid ID with an non-matching filename" do
        asset = FactoryGirl.create(:asset)
        get :download, :id => asset.id.to_s, :filename => "not-the-filename.pdf"
        response.code.to_i.should == 404
      end
    end

    context "access limiting on the public interface" do
      before(:each) do
        @restricted_asset = FactoryGirl.create(:access_limited_asset, organisation_slug: 'example-slug')
        @unrestricted_asset = FactoryGirl.create(:clean_asset)
      end

      it "404s requests to access limited documents" do
        get :download, id: @restricted_asset.id.to_s, filename: 'asset.png'
        response.status.should == 404
      end

      it "permits access to unrestricted documents" do
        get :download, id: @unrestricted_asset.id.to_s, filename: 'asset.png'
        response.should be_success
      end
    end

    context "access limiting on the private interface" do
      before(:each) do
        controller.stub(requested_via_private_vhost?: true)

        @asset = FactoryGirl.create(:access_limited_asset, organisation_slug: 'correct-organisation-slug')
      end

      it "bounces anonymous users to sign-on" do
        controller.should_receive(:require_signin_permission!)

        get :download, id: @asset.id.to_s, filename: 'asset.png'
      end

      it "404s requests to access limited documents if the user has the wrong organisation" do
        user = FactoryGirl.create(:user, organisation_slug: 'incorrect-organisation-slug')
        login_as(user)

        get :download, id: @asset.id.to_s, filename: 'asset.png'

        response.status.should == 404
      end

      it "permits access to access limited documents if the user has the right organisation" do
        user = FactoryGirl.create(:user, organisation_slug: 'correct-organisation-slug')
        login_as(user)

        get :download, id: @asset.id.to_s, filename: 'asset.png'

        response.should be_success
      end
    end
  end
end
