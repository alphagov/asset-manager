require "rails_helper"
require "services"
require "sidekiq_unique_jobs/testing"

RSpec.describe SvgScanBatchJob do
  let(:worker) { described_class.new }
  let(:asset) { FactoryBot.create(:virus_free_svg_asset) }
  let(:scanner) { instance_double(SvgScanner) }
  let(:storage) { instance_double(S3Storage) }
  let(:file) { Tempfile.new }

  before do
    allow(Services).to receive_messages(svg_scanner: scanner, cloud_storage: storage)
    allow(storage).to receive(:download).and_return(file)
  end

  context "when the file doesn't exist in S3" do
    before do
      context = Seahorse::Client::RequestContext.new
      error = Aws::S3::Errors::NoSuchKey.new(context, "The specified key does not exist.")
      allow(storage).to receive(:download).and_raise(error)
      allow(Rails.logger).to receive(:info).at_least(:once)
    end

    it "updates the asset's SVG scan state" do
      worker.perform(asset.id)

      expect(asset.reload.svg_scan_state).to eq("file_missing_from_s3")
    end

    it "logs that the asset is missing" do
      expect(Rails.logger).to receive(:info).with("#{asset.id} - SvgScanBatchJob - Asset missing from S3").once

      worker.perform(asset.id)
    end
  end

  context "when the asset doesn't yet know its file's mimetype" do
    before do
      asset.set(mime_type: nil)

      allow(Marcel::MimeType).to receive(:for).and_return("image/svg+xml")
      allow(scanner).to receive(:scan)
    end

    it "identifies and records it" do
      worker.perform(asset.id)

      expect(asset.reload.mime_type).to eq("image/svg+xml")
    end
  end

  context "when the file's mimetype is not 'image/svg+xml'" do
    before { asset.set(mime_type: "application/pdf") }

    it "does not perform a scan" do
      expect(scanner).not_to receive(:scan)

      worker.perform(asset.id)
    end
  end

  context "when the file's mimetype is 'image/svg+xml'" do
    before { asset.set(mime_type: "image/svg+xml") }

    it "calls out to the SvgScanner to scan the file" do
      expect(scanner).to receive(:scan).with(file.path)

      worker.perform(asset.id)
    end

    context "when the file is clean" do
      before { allow(scanner).to receive(:scan) }

      it "records that SVG scan state" do
        worker.perform(asset.id)

        expect(asset.reload.svg_scan_state).to eq("svg_clean")
      end

      it "records the time of the scan" do
        travel_to Time.zone.parse("2026-07-20 16:35")

        worker.perform(asset.id)

        expect(asset.reload.svg_scanned_at.to_s).to eq("2026-07-20 16:35:00 +0100")
      end
    end

    context "when the SVG asset is potentially unsafe" do
      let(:exception_message) { "SVG: Unsafe element detected: <script>" }
      let(:exception) { SvgDocument::UnsafeSvg.new(exception_message) }

      before do
        allow(scanner).to receive(:scan).and_raise(exception)
        allow(Rails.logger).to receive(:info).at_least(:once)
        allow(GovukError).to receive(:notify).at_least(:once)
      end

      it "records that SVG scan state" do
        worker.perform(asset.id)

        expect(asset.reload.svg_scan_state).to eq("svg_infected")
      end

      it "records the time of the scan" do
        travel_to Time.zone.parse("2026-07-20 16:35")

        worker.perform(asset.id)

        expect(asset.reload.svg_scanned_at.to_s).to eq("2026-07-20 16:35:00 +0100")
      end

      it "logs the failure" do
        expect(Rails.logger).to receive(:info).with("#{asset.id} - SvgScanBatchJob - SVG unsafe").once
        expect(GovukError).to receive(:notify).with(exception, extra: { id: asset.id, filename: asset.filename })

        worker.perform(asset.id)
      end
    end
  end
end
