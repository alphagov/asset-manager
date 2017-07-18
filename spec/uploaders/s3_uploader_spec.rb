require "rails_helper"

RSpec.describe S3Uploader, type: :uploader do
  let(:asset) { Asset.new(file: load_fixture_file("asset.png")) }
  subject { described_class.new(asset) }

  let(:object) { double(:object, upload_file: nil) }

  before do
    allow(subject).to receive(:upload).and_call_original
    allow(Aws::S3::Object).to receive(:new).and_return(object)
  end

  describe '#upload' do
    it 'creates an object in the named bucket with the asset id as a key' do
      expect(Aws::S3::Object).to receive(:new).with(bucket_name: Rails.configuration.bucket_name, key: asset.id.to_s)

      subject.upload
    end

    it 'uploads the object to S3' do
      expect(object).to receive(:upload_file).with(asset.file.path)

      subject.upload
    end

    context 'when uploading raises an exception' do
      before do
        class AnException < StandardError; end

        allow(object).to receive(:upload_file).and_raise(AnException)
      end

      it 'notifies Airbrake and re-raises the exception' do
        expect(Airbrake).to receive(:notify_or_ignore).with(AnException, params: { id: asset.id, file: asset.file.path })

        expect {
          subject.upload
        }.to raise_error(AnException)
      end
    end
  end

  describe '#download' do
    let(:body) { StringIO.new }
    let(:get_output_object) { double(:get_output_object, body: body) }

    it 'creates an object in the named bucket with the asset id as a key' do
      expect(Aws::S3::Object).to receive(:new).with(bucket_name: Rails.configuration.bucket_name, key: asset.id.to_s)

      subject.upload
    end

    it 'downloads the object from S3 and returns its body' do
      allow(object).to receive(:get).and_return(get_output_object)

      expect(subject.download).to eq(body)
    end
  end
end
