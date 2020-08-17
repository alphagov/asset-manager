require "rails_helper"

RSpec.describe "Healthcheck", type: :request do
  it "responds with json" do
    get "/healthcheck"

    expect(response.status).to eq(200)
    expect(response.media_type).to eq("application/json")
    expect { data }.not_to raise_error
  end

  context "when the healthchecks pass" do
    it "returns a status of 'ok'" do
      get "/healthcheck"
      expect(data.fetch(:status)).to eq("ok")
    end
  end

  context "when one of the healthchecks is warning" do
    let(:database_healthcheck) { Healthcheck::DatabaseHealthcheck.new }

    before do
      allow(Healthcheck::DatabaseHealthcheck)
        .to receive(:new).and_return(database_healthcheck)
      allow(database_healthcheck)
        .to receive(:status).and_return(:warning)
    end

    it "returns a status of 'warning'" do
      get "/healthcheck"
      expect(data.fetch(:status)).to eq("warning")
    end
  end

  context "when one of the healthchecks is critical" do
    let(:database_healthcheck) { Healthcheck::DatabaseHealthcheck.new }

    before do
      allow(Healthcheck::DatabaseHealthcheck)
        .to receive(:new).and_return(database_healthcheck)
      allow(database_healthcheck)
        .to receive(:status).and_return(:critical)
    end

    it "returns a status of 'critical'" do
      get "/healthcheck"
      expect(data.fetch(:status)).to eq("critical")
    end
  end

  it "includes useful information about each check" do
    get "/healthcheck"

    expect(data.fetch(:checks)).to include(
      database: { status: "ok" },
      redis: { status: "ok" },
    )
  end

private

  def data(body = response.body)
    JSON.parse(body).deep_symbolize_keys
  end
end
