require 'rails_helper'
RSpec.describe SaveToCloudStorageWorker, type: :worker do
  let(:worker) { described_class.new }

  describe "#perform" do
    let(:asset) { FactoryGirl.create(:clean_asset) }

    context 'when S3 bucket is configured' do
      let(:cloud_storage) { double(:cloud_storage) }

      before do
        allow(Services).to receive(:cloud_storage).and_return(cloud_storage)
      end

      it 'saves the asset to cloud storage' do
        expect(cloud_storage).to receive(:save).with(asset)

        worker.perform(asset)
      end

      context 'when an exception is raised' do
        let(:exception_class) { Class.new(StandardError) }
        let(:exception) { exception_class.new }

        before do
          allow(cloud_storage).to receive(:save).and_raise(exception)
        end

        it 'reports the exception to Errbit via Airbrake' do
          expect(Airbrake).to receive(:notify_or_ignore)
          .with(exception, params: { id: asset.id, filename: asset.filename })

          worker.perform(asset) rescue exception_class
        end

        it 're-raises the exception so Delayed::Job will re-try it' do
          allow(Airbrake).to receive(:notify_or_ignore)

          expect {
            worker.perform(asset)
          }.to raise_error(exception)
        end
      end
    end

    context 'when S3 bucket is not configured' do
      before do
        allow(AssetManager).to receive(:aws_s3_bucket_name).and_return(nil)
      end

      it 'does not attempt to build AWS S3 resource', disable_cloud_storage_stub: true do
        expect(Aws::Resources::Resource).not_to receive(:new)

        worker.perform(asset)
      end
    end
  end
end
