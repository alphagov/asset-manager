require "rails_helper"
require "services"
require "sidekiq_unique_jobs/testing"

RSpec.describe SvgScanJob do
  let(:worker) { described_class.new }
  let(:asset) { FactoryBot.create(:svg_asset_safe) }
  let(:scanner) { instance_double(SvgScanner) }

  before do
    allow(Services).to receive(:svg_scanner).and_return(scanner)
  end

  specify { expect(described_class).to have_valid_sidekiq_options }

  it "does not permit multiple jobs to be enqueued for the same asset" do
    SidekiqUniqueJobs.use_config(enabled: true) do
      expect { described_class.perform_in(1.minute, asset.id.to_s) }.to enqueue_sidekiq_job(described_class)
      expect { described_class.perform_in(1.minute, asset.id.to_s) }.not_to enqueue_sidekiq_job(described_class)
    end
  end

  it "calls out to the SvgScanner to scan the file" do
    expect(scanner).to receive(:scan).with(asset.file.path)

    worker.perform(asset.id)
  end

  context "when the file is clean" do
    before do
      allow(scanner).to receive(:scan).and_return(true)
    end

    context "but no longer matches the file associated with the asset" do
      before do
        allow(asset).to receive(:md5_hexdigest).twice.and_return("foo", "bar")
        allow(Asset).to receive(:find).with(asset.id).and_return(asset)
        allow(Rails.logger).to receive(:info).at_least(:once)
      end

      it "logs the job failure and does not update the asset's state" do
        worker.perform(asset.id)
        expect(Rails.logger).to have_received(:info).with("#{asset.id} SvgScanJob checksum failed").once
        expect(asset.reload).not_to be_clean
      end
    end

    it "sets the state to clean" do
      worker.perform(asset.id)

      asset.reload
      expect(asset).to be_clean
    end
  end

  context "when the asset is already marked as clean" do
    let(:asset) { FactoryBot.create(:svg_asset_clean) }

    it "does not SVG scan file" do
      expect(scanner).not_to receive(:scan)

      worker.perform(asset.id)
    end
  end

  context "when the asset is already marked as infected" do
    let(:asset) { FactoryBot.create(:svg_infected_asset) }

    it "does not SVG scan file" do
      expect(scanner).not_to receive(:scan)

      worker.perform(asset.id)
    end
  end

  context "when the asset is already marked as uploaded" do
    let(:asset) { FactoryBot.create(:svg_uploaded_asset) }

    it "does not SVG scan file" do
      expect(scanner).not_to receive(:scan)

      worker.perform(asset.id)
    end
  end

  context "when the SVG asset is unsafe" do
    let(:exception_message) { "SVG: Unsafe element detected: <script>" }
    let(:exception) { SvgDocument::UnsafeSvg.new(exception_message) }

    before do
      allow(scanner).to receive(:scan).and_raise(exception)
    end

    it "sets the state to infected if the SVG asset is unsafe" do
      worker.perform(asset.id)

      asset.reload
      expect(asset).to be_infected
    end

    it "sends an exception notification" do
      expect(GovukError).to receive(:notify)
        .with(exception, extra: { id: asset.id, filename: asset.filename })

      worker.perform(asset.id)
    end
  end
end
