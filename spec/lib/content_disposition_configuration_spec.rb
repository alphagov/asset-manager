require "rails_helper"

RSpec.describe ContentDispositionConfiguration do
  let(:config) { described_class.new(type: type) }
  let(:type) { "inline" }
  let(:asset) { FactoryBot.build(:asset) }

  describe "#type" do
    let(:type) { "attachment" }

    it "returns type supplied to constructor" do
      expect(config.type).to eq("attachment")
    end
  end

  describe "#options_for" do
    it "returns options including filename for asset" do
      expect(config.options_for(asset)).to include(filename: "asset.png")
    end

    it "returns options including disposition for asset" do
      expect(config.options_for(asset)).to include(disposition: "inline")
    end
  end

  describe "#header_for" do
    it "returns Content-Disposition header value" do
      expect(config.header_for(asset)).to eq(%(inline; filename="asset.png"))
    end
  end
end
