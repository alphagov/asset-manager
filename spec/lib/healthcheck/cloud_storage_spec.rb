require "healthcheck/cloud_storage"
require "services"
require "rails_helper"

RSpec.describe Healthcheck::CloudStorage do
  describe "#status" do
    let(:storage) { instance_double(S3Storage) }

    before do
      allow(Services).to receive(:cloud_storage).and_return(storage)
    end

    it "returns OK when connected to the storage service" do
      allow(storage).to receive(:healthy?).and_return(true)

      expect(described_class.new.status).to eq GovukHealthcheck::OK
    end

    it "returns CRITICAL when the storage connection fails" do
      allow(storage).to receive(:healthy?).and_return(false)

      expect(described_class.new.status).to eq GovukHealthcheck::CRITICAL
    end
  end
end
