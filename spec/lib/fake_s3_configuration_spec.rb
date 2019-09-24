require "rails_helper"
require "fake_s3_configuration"

RSpec.describe FakeS3Configuration do
  subject(:config) { described_class.new(env, govuk_config) }

  let(:env) { {} }
  let(:govuk_config) { instance_double(GovukConfiguration) }

  describe "#root" do
    it "returns directory path to fake S3 storage" do
      expect(config.root).to eq(Rails.root.join("fake-s3"))
    end
  end

  describe "#path_prefix" do
    it "returns path prefix to fake S3 route" do
      expect(config.path_prefix).to eq("/fake-s3")
    end
  end

  describe "#host" do
    context "when FAKE_S3_HOST is set in environment" do
      let(:env) { { "FAKE_S3_HOST" => "http://fake-s3-host" } }

      it "returns fake S3 host obtained from FAKE_S3_HOST value" do
        expect(config.host).to eq("http://fake-s3-host")
      end
    end

    context "when FAKE_S3_HOST is not set in environment" do
      before do
        allow(govuk_config).to receive(:app_host).and_return(app_host)
      end

      context "when app_host is set" do
        let(:app_host) { "http://example.com" }

        it "returns fake S3 host obtained from GOV.UK app_host" do
          expect(config.host).to eq("http://example.com")
        end
      end

      context "when app_host is not set" do
        let(:app_host) { nil }

        it "returns default fake S3 host for Rails app in development" do
          expect(config.host).to eq("http://localhost:3000")
        end
      end
    end
  end
end
