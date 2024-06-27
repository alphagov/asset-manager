require "rails_helper"
require "s3_configuration"

RSpec.describe S3Configuration do
  subject(:config) { described_class.new(env) }

  let(:env) { {} }

  describe ".build" do
    subject(:config_class) { described_class }

    let(:production) { false }

    before do
      allow(Rails.env).to receive(:production?).and_return(production)
    end

    it "returns instance of configuration" do
      expect(config_class.build(env)).to be_instance_of(config_class)
    end

    context "when Rails environment is production" do
      let(:production) { true }

      context "when AWS_S3_BUCKET_NAME env var is not present" do
        context "when fake S3 is allowed" do
          let(:env) { { "ALLOW_FAKE_S3_IN_PRODUCTION_FOR_PUBLISHING_E2E_TESTS" => "1" } }

          it "does not fail fast" do
            expect { config_class.build(env) }.not_to raise_error
          end
        end

        context "when fake S3 is not allowed" do
          it "fails fast by raising an exception" do
            expect { config_class.build(env) }
              .to raise_error("S3 bucket name not set")
          end
        end
      end

      context "when AWS_S3_BUCKET_NAME env var is present" do
        let(:env) { { "AWS_S3_BUCKET_NAME" => "s3-bucket-name" } }

        it "does not fail fast" do
          expect { config_class.build(env) }.not_to raise_error
        end
      end
    end

    context "when Rails environment is not production" do
      let(:production) { false }

      context "when AWS_S3_BUCKET_NAME env var is not present" do
        it "does not fail fast" do
          expect { config_class.build(env) }.not_to raise_error
        end
      end

      context "when AWS_S3_BUCKET_NAME env var is present" do
        let(:env) { { "AWS_S3_BUCKET_NAME" => "s3-bucket-name" } }

        it "does not fail fast" do
          expect { config_class.build(env) }.not_to raise_error
        end
      end
    end
  end

  describe "#bucket_name" do
    context "when AWS_S3_BUCKET_NAME env var is present" do
      let(:env) { { "AWS_S3_BUCKET_NAME" => "s3-bucket-name" } }

      it "returns S3 bucket name" do
        expect(config.bucket_name).to eq("s3-bucket-name")
      end
    end

    context "when AWS_S3_BUCKET_NAME env var is not present" do
      it "returns nil" do
        expect(config.bucket_name).to be_nil
      end
    end
  end

  describe "#configured?" do
    context "when bucket_name is set" do
      let(:env) { { "AWS_S3_BUCKET_NAME" => "s3-bucket-name" } }

      it "is considered to be configured" do
        expect(config).to be_configured
      end
    end

    context "when bucket_name is not set" do
      it "is considered not to be configured" do
        expect(config).not_to be_configured
      end
    end
  end

  describe "#fake?" do
    before do
      allow(Rails.env).to receive(:production?).and_return(production)
    end

    context "when not configured" do
      context "when Rails environment is not production" do
        let(:production) { false }

        it "is fake" do
          expect(config).to be_fake
        end
      end

      context "when Rails environment is production" do
        let(:production) { true }

        context "when fake S3 is allowed in production" do
          let(:env) { { "ALLOW_FAKE_S3_IN_PRODUCTION_FOR_PUBLISHING_E2E_TESTS" => "1" } }

          it "is fake" do
            expect(config).to be_fake
          end
        end

        context "when fake S3 is not allowed in production" do
          it "is not fake" do
            expect(config).not_to be_fake
          end
        end
      end
    end

    context "when configured" do
      let(:extra_env) { {} }
      let(:env) { { "AWS_S3_BUCKET_NAME" => "s3-bucket-name" }.merge(extra_env) }

      context "when Rails environment is not production" do
        let(:production) { false }

        it "is not fake" do
          expect(config).not_to be_fake
        end
      end

      context "when Rails environment is production" do
        let(:production) { true }

        context "when fake S3 is allowed in production" do
          let(:extra_env) { { "ALLOW_FAKE_S3_IN_PRODUCTION_FOR_PUBLISHING_E2E_TESTS" => "1" } }

          it "is not fake" do
            expect(config).not_to be_fake
          end
        end

        context "when fake S3 is not allowed in production" do
          it "is not fake" do
            expect(config).not_to be_fake
          end
        end
      end
    end
  end
end
