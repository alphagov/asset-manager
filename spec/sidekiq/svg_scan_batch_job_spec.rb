require "rails_helper"
require "services"
require "sidekiq_unique_jobs/testing"

RSpec.describe SvgScanBatchJob do
  let(:worker) { described_class.new }
  let(:asset) { FactoryBot.create(:svg_asset_safe) }
  let(:scanner) { instance_double(SvgScanner) }
  let(:storage) { instance_double(S3Storage) }
  let(:file) { Tempfile.new }

  before do
    allow(Services).to receive_messages(svg_scanner: scanner, cloud_storage: storage)
    allow(storage).to receive(:download).and_return(file)
  end

  specify { expect(described_class).to have_valid_sidekiq_options }

  it "does not permit multiple jobs to be enqueued for the same asset" do
    SidekiqUniqueJobs.use_config(enabled: true) do
      expect { described_class.perform_in(1.minute, asset.id.to_s) }.to enqueue_sidekiq_job(described_class)
      expect { described_class.perform_in(1.minute, asset.id.to_s) }.not_to enqueue_sidekiq_job(described_class)
    end
  end

  context "when the file doesn't exist in S3" do
    before do
      context = Seahorse::Client::RequestContext.new
      error = Aws::S3::Errors::NoSuchKey.new(context, "The specified key does not exist.")
      allow(storage).to receive(:download).and_raise(error)
      allow(Rails.logger).to receive(:info).at_least(:once)
    end

    it "does nothing" do
      worker.perform(asset.id)
      expect(Rails.logger).to have_received(:info).with("#{asset.id} - SvgScanBatchJob#perform - Asset missing from S3").once
    end
  end

  context "when the file's mimetype is not 'image/svg+xml'" do
    before do
      allow(Marcel::MimeType).to receive(:for).and_return("not-svg")
    end

    it "does nothing" do
      expect(scanner).not_to receive(:scan)
      worker.perform(asset.id)
    end
  end

  context "when the file's mimetype is 'image/svg+xml'" do
    before do
      allow(Marcel::MimeType).to receive(:for).and_return("image/svg+xml")
    end

    it "calls out to the SvgScanner to scan the file" do
      expect(scanner).to receive(:scan).with(file.path)
      worker.perform(asset.id)
    end

    context "when the file is clean" do
      before do
        allow(scanner).to receive(:scan)
      end

      it "records that svg_scanned_safe is true" do
        worker.perform(asset.id)

        asset.reload
        expect(asset.svg_scanned_safe).to be true
      end

      it "records the datetime of the scan" do
        worker.perform(asset.id)

        asset.reload
        expect(asset.svg_scanned_at).not_to be_nil
      end
    end

    context "when the SVG asset is unsafe" do
      let(:exception_message) { "SVG: Unsafe element detected: <script>" }
      let(:exception) { SvgDocument::UnsafeSvg.new(exception_message) }

      before do
        allow(scanner).to receive(:scan).and_raise(exception)
        allow(Rails.logger).to receive(:warn).at_least(:once)
        allow(GovukError).to receive(:notify).at_least(:once)
      end

      it "records that svg_scanned_safe is false" do
        worker.perform(asset.id)

        asset.reload
        expect(asset.svg_scanned_safe).to be false
      end

      it "logs the failure" do
        worker.perform(asset.id)

        expect(Rails.logger).to have_received(:warn).with("#{asset.id} - SVG Scan - File #{asset.filename} marked as unsafe").once
        expect(GovukError).to have_received(:notify).with(exception, extra: { id: asset.id, filename: asset.filename })
      end

      it "records the datetime of the scan" do
        worker.perform(asset.id)

        asset.reload
        expect(asset.svg_scanned_at).not_to be_nil
      end
    end
  end
end
