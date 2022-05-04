require "rails_helper"
require "s3_storage"

RSpec.describe S3Storage do
  let(:storage) { described_class.new(bucket_name) }
  let(:bucket_name) { "bucket-name" }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_object) { instance_double(Aws::S3::Object) }
  let(:asset) { FactoryBot.create(:asset) }
  let(:key) { asset.uuid }
  let(:s3_object_params) { { bucket_name: bucket_name, key: key } }
  let(:s3_head_object_params) { { bucket: bucket_name, key: key } }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(Aws::S3::Object).to receive(:new)
      .with(s3_object_params).and_return(s3_object)
  end

  describe ".build" do
    let(:s3_configured) { true }
    let(:s3_fake) { false }
    let(:s3_config) { instance_double(S3Configuration, bucket_name: bucket_name, configured?: s3_configured, fake?: s3_fake) }

    before do
      allow(AssetManager).to receive(:s3).and_return(s3_config)
    end

    it "builds an instance of S3Storage" do
      expect(described_class.build).to be_instance_of(described_class)
    end

    context "when S3 is not configured" do
      let(:s3_configured) { false }

      context "and fake S3 is enabled" do
        let(:s3_fake) { true }

        it "builds an instance of S3Storage::Fake" do
          expect(described_class.build).to be_instance_of(S3Storage::Fake)
        end
      end

      context "and fake S3 is not enabled" do
        let(:s3_fake) { false }

        it "raises an exception" do
          expect { described_class.build }.to raise_error("AWS S3 bucket not correctly configured")
        end
      end
    end
  end

  describe "#save" do
    before do
      allow(s3_object).to receive(:exists?).and_return(false)
    end

    it "uploads file to S3 bucket" do
      allow(s3_object).to receive(:upload_file).with(asset.file.path, anything).and_return(true)
      storage.upload(asset)
      expect(s3_object).to have_received(:upload_file).with(asset.file.path, anything)
    end

    it "sets md5-hexdigest custom metadata on S3 object" do
      expected_metadata = { "md5-hexdigest" => asset.md5_hexdigest }
      allow(s3_object).to receive(:upload_file)
        .with(anything, include(metadata: include(expected_metadata)))
        .and_return(true)

      storage.upload(asset)

      expect(s3_object).to have_received(:upload_file)
        .with(anything, include(metadata: include(expected_metadata)))
    end

    context "when Aws::S3::Object#upload_file returns false" do
      before do
        allow(s3_object).to receive(:upload_file).and_return(false)
      end

      it "raises ObjectUploadFailedError exception" do
        error_message = "Aws::S3::Object#upload_file returned false for asset ID: #{asset.id}"

        expect { storage.upload(asset) }
          .to raise_error(S3Storage::ObjectUploadFailedError, error_message)
      end
    end

    context "when Aws::S3::Object#upload_file raises Aws::S3::MultipartUploadError" do
      let(:exception) { Aws::S3::MultipartUploadError.new("message", [RuntimeError.new]) }

      before do
        allow(s3_object).to receive(:upload_file)
          .and_raise(exception)
      end

      it "raises ObjectUploadFailedError exception" do
        error_message = "Aws::S3::Object#upload_file raised #{exception.inspect} for asset ID: #{asset.id}"

        expect { storage.upload(asset) }
          .to raise_error(S3Storage::ObjectUploadFailedError, error_message)
      end
    end

    context "when S3 object already exists" do
      let(:default_metadata) { { "md5-hexdigest" => md5_hexdigest } }
      let(:metadata) { default_metadata }

      before do
        allow(s3_object).to receive(:exists?).and_return(true)

        allow(s3_client).to receive(:head_object).and_return(
          Aws::S3::Types::HeadObjectOutput.new(metadata: metadata),
        )
      end

      context "and MD5 hex digest does match" do
        let(:md5_hexdigest) { asset.md5_hexdigest }

        it "does not upload file to S3" do
          expect(s3_object).not_to receive(:upload_file)

          storage.upload(asset)
        end

        context "but force options is set" do
          it "uploads file to S3" do
            allow(s3_object).to receive(:upload_file).and_return(true)
            storage.upload(asset, force: true)
            expect(s3_object).to have_received(:upload_file)
          end
        end
      end

      context "and MD5 hex digest does not match" do
        let(:md5_hexdigest) { "does-not-match" }

        it "uploads file to S3" do
          allow(s3_object).to receive(:upload_file).and_return(true)
          storage.upload(asset)
          expect(s3_object).to have_received(:upload_file)
        end

        context "and object has existing metadata" do
          let(:existing_metadata) { { "existing-key" => "existing-value" } }
          let(:metadata) { default_metadata.merge(existing_metadata) }

          it "uploads file to S3 with existing metadata" do
            expect(s3_object).to receive(:upload_file).and_return(true)
              .with(anything, include(metadata: include(existing_metadata)))

            storage.upload(asset)
          end
        end
      end
    end
  end

  describe "#delete" do
    it "deletes the file from the S3 bucket" do
      allow(s3_object).to receive(:delete).and_return(true)
      storage.delete(asset)
      expect(s3_object).to have_received(:delete)
    end
  end

  describe "#presigned_url_for" do
    it "returns presigned URL for GET request to asset on S3 by default" do
      allow(s3_object).to receive(:presigned_url)
        .with("get", expires_in: 1.minute).and_return("presigned-url")
      expect(storage.presigned_url_for(asset)).to eq("presigned-url")
    end

    it "returns presigned URL for HEAD request to asset on S3 when http_method specified" do
      allow(s3_object).to receive(:presigned_url)
        .with("head", expires_in: 1.minute).and_return("presigned-url")
      expect(storage.presigned_url_for(asset, http_method: "HEAD")).to eq("presigned-url")
    end
  end

  describe "#exists?" do
    before do
      allow(s3_object).to receive(:exists?).and_return(exists_on_s3)
    end

    context "when asset does not exist on S3" do
      let(:exists_on_s3) { false }

      it "returns falsey" do
        expect(storage).not_to exist(asset)
      end
    end

    context "when asset does exist on S3" do
      let(:exists_on_s3) { true }

      it "returns truthy" do
        expect(storage).to exist(asset)
      end
    end
  end

  describe "#never_replicated?" do
    context "when asset does not exist on S3" do
      let(:not_found_error) { Aws::S3::Errors::NotFound.new(nil, nil) }

      before do
        allow(s3_client).to receive(:head_object)
          .with(s3_head_object_params).and_raise(not_found_error)
      end

      it "raises exception" do
        expect { storage.never_replicated?(asset) }
          .to raise_error(S3Storage::ObjectNotFoundError)
      end
    end

    context "when asset does exist on S3" do
      let(:attributes) { { replication_status: replication_status } }
      let(:s3_result) { Aws::S3::Types::HeadObjectOutput.new(attributes) }

      before do
        allow(s3_client).to receive(:head_object)
          .with(s3_head_object_params).and_return(s3_result)
      end

      context "and asset has no replication status" do
        let(:replication_status) { nil }

        it "returns truthy" do
          expect(storage).to be_never_replicated(asset)
        end
      end

      context "and asset has replication status" do
        let(:replication_status) { "COMPLETED" }

        it "returns falsey" do
          expect(storage).not_to be_never_replicated(asset)
        end
      end
    end
  end

  describe "#replicated?" do
    context "when asset does not exist on S3" do
      let(:not_found_error) { Aws::S3::Errors::NotFound.new(nil, nil) }

      before do
        allow(s3_client).to receive(:head_object)
          .with(s3_head_object_params).and_raise(not_found_error)
      end

      it "raises exception" do
        expect { storage.replicated?(asset) }
          .to raise_error(S3Storage::ObjectNotFoundError)
      end
    end

    context "when asset does exist on S3" do
      let(:attributes) { { replication_status: replication_status } }
      let(:s3_result) { Aws::S3::Types::HeadObjectOutput.new(attributes) }

      before do
        allow(s3_client).to receive(:head_object)
          .with(s3_head_object_params).and_return(s3_result)
      end

      context "and asset has no replication status" do
        let(:replication_status) { nil }

        it "returns falsey" do
          expect(storage).not_to be_replicated(asset)
        end
      end

      context "and asset replication status is COMPLETED" do
        let(:replication_status) { "COMPLETED" }

        it "returns truthy" do
          expect(storage).to be_replicated(asset)
        end
      end
    end
  end

  describe "#metadata_for" do
    context "when S3 object does not exist" do
      let(:not_found_error) { Aws::S3::Errors::NotFound.new(nil, nil) }

      before do
        allow(s3_client).to receive(:head_object)
          .with(s3_head_object_params).and_raise(not_found_error)
      end

      it "raises exception" do
        expect { storage.metadata_for(asset) }
          .to raise_error(S3Storage::ObjectNotFoundError)
      end
    end

    context "when S3 object does exist" do
      let(:metadata) { { "key" => "value" } }
      let(:attributes) { { metadata: metadata } }
      let(:s3_result) { Aws::S3::Types::HeadObjectOutput.new(attributes) }

      before do
        allow(s3_client).to receive(:head_object)
          .with(s3_head_object_params).and_return(s3_result)
      end

      it "returns metadata from S3 object" do
        expect(storage.metadata_for(asset)).to eq(metadata)
      end
    end
  end
end
