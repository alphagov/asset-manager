require 'rails_helper'
require 's3_storage'

RSpec.describe S3Storage do
  subject { described_class.build(bucket_name) }

  let(:bucket_name) { 'bucket-name' }
  let(:s3_object) { instance_double(Aws::S3::Object) }
  let(:asset) { FactoryGirl.build(:asset) }
  let(:s3_object_params) { { bucket_name: bucket_name, key: asset.id.to_s } }

  before do
    allow(Aws::S3::Object).to receive(:new).with(s3_object_params).and_return(s3_object)
  end

  describe '#save' do
    it 'uploads file to S3 bucket' do
      expect(s3_object).to receive(:upload_file).with(asset.file.path, anything)

      subject.save(asset)
    end

    it 'passes options to Aws::S3::Object#upload_file' do
      expect(s3_object).to receive(:upload_file).with(anything, cache_control: 'cache-control-header')

      subject.save(asset, cache_control: 'cache-control-header')
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
        }.to raise_error(S3Storage::NotConfiguredError, 'AWS S3 bucket not correctly configured')
      end
    end
  end

  describe '#public_url_for' do
    before do
      allow(AssetManager).to receive(:aws_s3_use_virtual_host).and_return(use_virtual_host)
    end

    context 'when configured not to use virtual host' do
      let(:use_virtual_host) { false }

      it 'returns public URL for asset on S3' do
        allow(s3_object).to receive(:public_url).with(virtual_host: false).and_return('public-url')
        expect(subject.public_url_for(asset)).to eq('public-url')
      end
    end

    context 'when configured to use virtual host' do
      let(:use_virtual_host) { true }

      it 'returns public URL for asset on S3 using virtual host' do
        allow(s3_object).to receive(:public_url).with(virtual_host: true).and_return('public-url')
        expect(subject.public_url_for(asset)).to eq('public-url')
      end
    end
  end

  describe '#presigned_url_for' do
    before do
      allow(AssetManager).to receive(:aws_s3_use_virtual_host).and_return(use_virtual_host)
    end

    context 'when configured not to use virtual host' do
      let(:use_virtual_host) { false }

      it 'returns presigned URL for asset on S3' do
        allow(s3_object).to receive(:presigned_url).with(:get, expires_in: 1.minute, virtual_host: false).and_return('presigned-url')
        expect(subject.presigned_url_for(asset)).to eq('presigned-url')
      end
    end

    context 'when configured to use virtual host' do
      let(:use_virtual_host) { true }

      it 'returns presigned URL for asset on S3 using virtual host' do
        allow(s3_object).to receive(:presigned_url).with(:get, expires_in: 1.minute, virtual_host: true).and_return('presigned-url')
        expect(subject.presigned_url_for(asset)).to eq('presigned-url')
      end
    end
  end
end
