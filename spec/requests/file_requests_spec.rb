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
end
