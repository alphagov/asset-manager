require "spec_helper"

describe "Healthcheck" do

  it "should respond with success on the healthehcek path" do
    get "/healthcheck"
    response.status.should == 200
    response.content_type.should == "text/plain"
    response.body.should == "OK"
  end
end
