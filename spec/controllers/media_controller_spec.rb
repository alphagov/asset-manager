require "spec_helper"

describe MediaController do

  describe "GET 'download'" do
    context "with a valid clean file" do
      before :each do
        @asset = FactoryGirl.create(:clean_asset)
      end

      def do_get
        get :download, :id => @asset.id.to_s, :filename => @asset.file.to_s.split('/').last
      end

      it "should be successful" do
        do_get
        response.should be_redirect
      end

      it "should send the file using send_file" do
        controller.should_receive(:redirect_to).with(@asset.file.to_s)
        controller.stub(:render) # prevent template_not_found errors because we intercepted redirect_to

        do_get
      end

      it "should redirect to the correct location" do
        do_get
        response.headers["Location"].should == @asset.file.to_s
      end
    end

    context "with an unscanned file" do
      before :each do
        @asset = FactoryGirl.create(:asset)
      end

      it "should return a 404" do
        get :download, :id => @asset.id.to_s, :filename => @asset.file.to_s.split('/').last
        response.code.to_i.should == 404
      end
    end

    context "with an infected file" do
      before :each do
        @asset = FactoryGirl.create(:infected_asset)
      end

      it "should return a 404" do
        get :download, :id => @asset.id.to_s, :filename => @asset.file.to_s.split('/').last
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
  end
end
