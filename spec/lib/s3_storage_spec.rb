require 'rails_helper'
require 's3_storage'

RSpec.describe S3Storage do
  subject { described_class.build(bucket_name) }

  let(:bucket_name) { 'bucket-name' }
  let(:s3_client) { instance_double(Aws::S3::Client) }
  let(:s3_object) { instance_double(Aws::S3::Object) }
  let(:asset) { FactoryGirl.create(:asset) }
  let(:key) { asset.uuid }
  let(:s3_object_params) { { bucket_name: bucket_name, key: key } }
  let(:s3_head_object_params) { { bucket: bucket_name, key: key } }

  before do
    allow(Aws::S3::Client).to receive(:new).and_return(s3_client)
    allow(Aws::S3::Object).to receive(:new).with(s3_object_params).and_return(s3_object)
  end

  describe '#save' do
    let(:not_found_error) { Aws::S3::Errors::NotFound.new(nil, nil) }

    before do
      allow(s3_client).to receive(:head_object).with(s3_head_object_params).and_raise(not_found_error)
    end

    it 'uploads file to S3 bucket' do
      expect(s3_object).to receive(:upload_file).with(asset.file.path, anything)

      subject.save(asset)
    end

    it 'sets md5-hexdigest custom metadata on S3 object' do
      expected_metadata = include(metadata: include('md5-hexdigest' => asset.md5_hexdigest))
      expect(s3_object).to receive(:upload_file).with(anything, expected_metadata)

      subject.save(asset)
    end

    it 'passes options to Aws::S3::Object#upload_file' do
      expect(s3_object).to receive(:upload_file).with(anything, include(cache_control: 'cache-control-header'))

      subject.save(asset, cache_control: 'cache-control-header')
    end

    context 'when S3 object already exists' do
      let(:attributes) { { metadata: { 'md5-hexdigest' => md5_hexdigest } } }
      let(:s3_result) { Aws::S3::Types::HeadObjectOutput.new(attributes) }

      before do
        allow(s3_client).to receive(:head_object).with(s3_head_object_params).and_return(s3_result)
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
      end
    end

    context 'when bucket name is blank' do
      let(:bucket_name) { '' }

      it 'does not upload file to S3 bucket' do
        expect(Aws::S3::Object).not_to receive(:new)

        subject.save(asset)
      end
    end
  end

  describe '#load' do
    let(:get_object_output) { instance_double(Aws::S3::Types::GetObjectOutput) }
    let(:io) { StringIO.new('s3-object-data') }

    before do
      allow(s3_object).to receive(:get).and_return(get_object_output)
      allow(get_object_output).to receive(:body).and_return(io)
    end

    it 'downloads file from S3 bucket' do
      expect(subject.load(asset)).to eq(io)
    end

    context 'when bucket name is blank' do
      let(:bucket_name) { '' }

      it 'raises NotConfiguredError exception' do
        expect {
          subject.load(asset)
        }.to raise_error(S3Storage::NotConfiguredError)
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
        allow(s3_object).to receive(:presigned_url).with('GET', expires_in: 1.minute, virtual_host: false).and_return('presigned-url')
        expect(subject.presigned_url_for(asset)).to eq('presigned-url')
      end

      it 'returns presigned URL for HEAD request to asset on S3 when http_method specified' do
        allow(s3_object).to receive(:presigned_url).with('HEAD', expires_in: 1.minute, virtual_host: false).and_return('presigned-url')
        expect(subject.presigned_url_for(asset, http_method: 'HEAD')).to eq('presigned-url')
      end

      context 'when bucket name is blank' do
        let(:bucket_name) { '' }

        it 'raises NotConfiguredError exception' do
          expect {
            subject.presigned_url_for(asset)
          }.to raise_error(S3Storage::NotConfiguredError)
        end
      end
    end

    context 'when configured to use virtual host' do
      let(:use_virtual_host) { true }

      it 'returns presigned URL for asset on S3 using virtual host' do
        allow(s3_object).to receive(:presigned_url).with('GET', expires_in: 1.minute, virtual_host: true).and_return('presigned-url')
        expect(subject.presigned_url_for(asset)).to eq('presigned-url')
      end
    end
  end

  describe 'S3Storage::Null' do
    it 'implements all public methods defined on S3Storage' do
      methods = described_class.public_instance_methods(false)
      expect(S3Storage::Null.public_instance_methods(false)).to include(*methods)
    end
  end
end
