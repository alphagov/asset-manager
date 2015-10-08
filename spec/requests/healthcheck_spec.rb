require "spec_helper"

describe "Healthcheck" do

  it "should respond with success on the healthehcek path" do
    get "/healthcheck"
    expect(response.status).to eq(200)
    expect(response.content_type).to eq("text/plain")
    expect(response.body).to eq("OK")
  end
end
