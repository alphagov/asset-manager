require "rails_helper"

RSpec.describe "Healthcheck", type: :request do
  it "responds with success on the healthcheck path" do
    get "/healthcheck"
    expect(response).to have_http_status(:success)
    expect(response.content_type).to eq("text/plain")
    expect(response.body).to eq("OK")
  end
end
