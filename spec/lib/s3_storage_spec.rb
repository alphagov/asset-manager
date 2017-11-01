require 'rails_helper'
require 's3_storage'

RSpec.describe S3Storage do
  subject { described_class.new(bucket_name) }

  let(:bucket_name) { 'bucket-name' }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_object) { instance_double(Aws::S3::Object) }
  let(:asset) { FactoryGirl.create(:asset) }
  let(:key) { asset.uuid }
  let(:s3_object_params) { { bucket_name: bucket_name, key: key } }
  let(:s3_head_object_params) { { bucket: bucket_name, key: key } }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(Aws::S3::Object).to receive(:new)
      .with(s3_object_params).and_return(s3_object)
  end

  describe '.build' do
    subject { described_class.build(bucket_name) }

    it 'builds an instance of S3Storage' do
      expect(subject).to be_instance_of(described_class)
    end

    context 'when bucket_name is blank' do
      let(:bucket_name) { '' }
      let(:rails_env) { double('rails-env') }

      before do
        allow(Rails).to receive(:env).and_return(rails_env)
        allow(rails_env).to receive(:development?).and_return(is_development)
      end

      context 'and Rails environment is development' do
        let(:is_development) { true }

        it 'builds an instance of S3Storage::Fake' do
          expect(subject).to be_instance_of(S3Storage::Fake)
        end
      end

      context 'and Rails environment is not development' do
        let(:is_development) { false }

        it 'builds an instance of S3Storage::Null' do
          expect(subject).to be_instance_of(S3Storage::Null)
        end
      end
    end
  end

  describe '#save' do
    before do
      allow(s3_object).to receive(:exists?).and_return(false)
    end

    it 'uploads file to S3 bucket' do
      expect(s3_object).to receive(:upload_file).with(asset.file.path, anything)

      subject.save(asset)
    end

    it 'sets md5-hexdigest custom metadata on S3 object' do
      expected_metadata = { 'md5-hexdigest' => asset.md5_hexdigest }
      expect(s3_object).to receive(:upload_file)
        .with(anything, include(metadata: include(expected_metadata)))

      subject.save(asset)
    end

    context 'when S3 object already exists' do
      let(:default_metadata) { { 'md5-hexdigest' => md5_hexdigest } }
      let(:metadata) { default_metadata }
      let(:attributes) { { metadata: metadata } }
      let(:s3_result) { Aws::S3::Types::HeadObjectOutput.new(attributes) }

      before do
        allow(s3_object).to receive(:exists?).and_return(true)
        allow(s3_client).to receive(:head_object)
          .with(s3_head_object_params).and_return(s3_result)
      end

      context 'and MD5 hex digest does match' do
        let(:md5_hexdigest) { asset.md5_hexdigest }

        it 'does not upload file to S3' do
          expect(s3_object).not_to receive(:upload_file)

          subject.save(asset)
        end
      end

      context 'and MD5 hex digest does not match' do
        let(:md5_hexdigest) { 'does-not-match' }

        it 'uploads file to S3' do
          expect(s3_object).to receive(:upload_file)

          subject.save(asset)
        end

        context 'and object has existing metadata' do
          let(:existing_metadata) { { 'existing-key' => 'existing-value' } }
          let(:metadata) { default_metadata.merge(existing_metadata) }

          it 'uploads file to S3 with existing metadata' do
            expect(s3_object).to receive(:upload_file)
              .with(anything, include(metadata: include(existing_metadata)))

            subject.save(asset)
          end
        end
      end
    end
  end

  describe '#presigned_url_for' do
    before do
      allow(AssetManager).to receive(:aws_s3_use_virtual_host).and_return(use_virtual_host)
    end

    context 'when configured not to use virtual host' do
      let(:use_virtual_host) { false }

      it 'returns presigned URL for GET request to asset on S3 by default' do
        allow(s3_object).to receive(:presigned_url)
          .with('GET', expires_in: 1.minute, virtual_host: false).and_return('presigned-url')
        expect(subject.presigned_url_for(asset)).to eq('presigned-url')
      end

      it 'returns presigned URL for HEAD request to asset on S3 when http_method specified' do
        allow(s3_object).to receive(:presigned_url)
          .with('HEAD', expires_in: 1.minute, virtual_host: false).and_return('presigned-url')
        expect(subject.presigned_url_for(asset, http_method: 'HEAD')).to eq('presigned-url')
      end
    end

    context 'when configured to use virtual host' do
      let(:use_virtual_host) { true }

      it 'returns presigned URL for asset on S3 using virtual host' do
        allow(s3_object).to receive(:presigned_url)
          .with('GET', expires_in: 1.minute, virtual_host: true).and_return('presigned-url')
        expect(subject.presigned_url_for(asset)).to eq('presigned-url')
      end
    end
  end

  describe '#exists?' do
    before do
      allow(s3_object).to receive(:exists?).and_return(exists_on_s3)
    end

    context 'when asset does not exist on S3' do
      let(:exists_on_s3) { false }

      it 'returns falsey' do
        expect(subject.exists?(asset)).to be_falsey
      end
    end

    context 'when asset does exist on S3' do
      let(:exists_on_s3) { true }

      it 'returns truthy' do
        expect(subject.exists?(asset)).to be_truthy
      end
    end
  end

  describe '#metadata_for' do
    context 'when S3 object does not exist' do
      let(:not_found_error) { Aws::S3::Errors::NotFound.new(nil, nil) }

      before do
        allow(s3_client).to receive(:head_object)
          .with(s3_head_object_params).and_raise(not_found_error)
      end

      it 'raises exception' do
        expect { subject.metadata_for(asset) }
          .to raise_error(S3Storage::ObjectNotFoundError)
      end
    end
  end
end
