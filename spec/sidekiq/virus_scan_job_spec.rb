require "rails_helper"
require "services"
require "sidekiq_unique_jobs/testing"

RSpec.describe VirusScanJob do
  let(:worker) { described_class.new }
  let(:asset) { FactoryBot.create(:asset) }
  let(:scanner) { instance_double(VirusScanner) }

  before do
    allow(Services).to receive(:virus_scanner).and_return(scanner)
  end

  specify { expect(described_class).to have_valid_sidekiq_options }

  it "does not permit multiple jobs to be enqueued for the same asset" do
    SidekiqUniqueJobs.use_config(enabled: true) do
      expect { described_class.perform_in(1.minute, asset.id.to_s) }.to enqueue_sidekiq_job(described_class)
      expect { described_class.perform_in(1.minute, asset.id.to_s) }.not_to enqueue_sidekiq_job(described_class)
    end
  end

  it "calls out to the VirusScanner to scan the file" do
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

      it "logs the mismatch, queues a new scan and does not update the asset's state" do
        expect(described_class).to receive(:perform_async).with(asset.id.to_s)

        worker.perform(asset.id)

        expect(Rails.logger).to have_received(:info).with("#{asset.id} - VirusScanJob - Checksum failed; queueing a new scan").once
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
    let(:asset) { FactoryBot.create(:virus_free_asset) }

    it "does not virus scan file" do
      expect(scanner).not_to receive(:scan)

      worker.perform(asset.id)
    end
  end

  context "when the asset is already marked as infected" do
    let(:asset) { FactoryBot.create(:virus_infected_asset) }

    it "does not virus scan file" do
      expect(scanner).not_to receive(:scan)

      worker.perform(asset.id)
    end
  end

  context "when the asset is already marked as uploaded" do
    let(:asset) { FactoryBot.create(:uploaded_asset) }

    it "does not virus scan file" do
      expect(scanner).not_to receive(:scan)

      worker.perform(asset.id)
    end
  end

  context "when a virus is found" do
    let(:exception_message) { "/path/to/file: Eicar-Test-Signature FOUND" }
    let(:exception) { VirusScanner::InfectedFile.new(exception_message) }

    before do
      allow(scanner).to receive(:scan).and_raise(exception)
      allow(Rails.logger).to receive(:warn).at_least(:once)
    end

    it "sets the state to infected if a virus is found" do
      worker.perform(asset.id)

      asset.reload
      expect(asset).to be_infected
    end

    it "logs the failure" do
      worker.perform(asset.id)

      expect(Rails.logger).to have_received(:warn).with("#{asset.id} - VirusScanJob - File #{asset.filename} marked as infected").once
    end
  end

  context "when the scanner errors because the scanned file no longer exists" do
    let(:exception) { VirusScanner::Error.new("/path/to/file.pdf: Can't access file ERROR") }

    before do
      allow(scanner).to receive(:scan).and_raise(exception)
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with(asset.file.path).and_return(false)
      allow(Rails.logger).to receive(:warn).at_least(:once)
    end

    it "does not raise, does not update the asset's state and does not retry" do
      expect { worker.perform(asset.id) }.not_to raise_error

      asset.reload
      expect(asset).to be_unscanned
      expect(Rails.logger).to have_received(:warn).with("#{asset.id} - VirusScanJob - File removed during scan and no new file available to scan").once
    end

    context "and the asset has since been re-uploaded with a new file" do
      let(:reuploaded_asset) do
        instance_double(
          Asset,
          id: asset.id,
          unscanned?: true,
          redirect_url: nil,
          file: double(path: "/path/to/new/file.pdf"),
        )
      end

      before do
        allow(Asset).to receive(:find).with(asset.id).and_return(asset)
        allow(asset).to receive(:reload).and_return(reuploaded_asset)
        allow(File).to receive(:exist?).with("/path/to/new/file.pdf").and_return(true)
      end

      it "queues a scan of the current file instead of retrying" do
        expect(reuploaded_asset).to receive(:schedule_virus_scan)

        expect { worker.perform(asset.id) }.not_to raise_error

        expect(Rails.logger).to have_received(:warn).with("#{asset.id} - VirusScanJob - File replaced during scan; queueing scan of the current file").once
      end
    end
  end

  context "when the scanner errors but the file still exists" do
    let(:exception) { VirusScanner::Error.new("WARNING: Can't connect to clamd") }

    before do
      allow(scanner).to receive(:scan).and_raise(exception)
    end

    it "re-raises so that Sidekiq can retry the job" do
      expect { worker.perform(asset.id) }.to raise_error(VirusScanner::Error)
    end
  end
end
