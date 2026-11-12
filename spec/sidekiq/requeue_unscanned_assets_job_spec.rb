require "rails_helper"
require "sidekiq_unique_jobs/testing"

RSpec.describe RequeueUnscannedAssetsJob do
  subject(:sweep) { worker.perform(batch_size, age_in_minutes) }

  let(:worker) { described_class.new }
  let(:batch_size) { described_class::DEFAULT_BATCH_SIZE }
  let(:age_in_minutes) { described_class::DEFAULT_AGE_MINUTES }

  specify { expect(described_class).to have_valid_sidekiq_options }

  describe "#perform" do
    context "when no unscanned assets are stuck" do
      before do
        FactoryBot.create(:asset)
        FactoryBot.create(:virus_free_asset).set(updated_at: 2.hours.ago)
        FactoryBot.create(:deleted_asset).set(updated_at: 2.hours.ago)
        FactoryBot.create(
          :asset,
          redirect_url: "https://www.gov.uk/random",
        ).set(updated_at: 2.hours.ago)
      end

      it "does not enqueue any virus scans" do
        expect(VirusScanJob).not_to receive(:perform_async)

        sweep
      end

      it "logs that nothing was found" do
        allow(Rails.logger).to receive(:info)

        expect(Rails.logger).to receive(:info)
          .with(/#{described_class.name} - No unscanned assets older than 30 minutes found/)
        expect(Rails.logger).to receive(:info)
          .with(/#{described_class.name} - No unscanned assets without file found/)

        sweep
      end
    end

    context "when unscanned assets are stuck" do
      let!(:stuck_asset) { FactoryBot.create(:asset).set(updated_at: 2.hours.ago) }
      let!(:whitehall_stuck_asset) { FactoryBot.create(:whitehall_asset).set(updated_at: 2.hours.ago) }
      let!(:stuck_asset_with_file_missing) do
        asset = FactoryBot.create(:asset)
        FileUtils.rm_rf(File.dirname(asset.file.path))
        asset.set(updated_at: 2.hours.ago)
      end

      it "enqueues scans for those whose files exist and removes the others" do
        allow(VirusScanJob).to receive(:perform_async)
        expect(VirusScanJob).to receive(:perform_async).with(stuck_asset.id.to_s)
        expect(VirusScanJob).to receive(:perform_async).with(whitehall_stuck_asset.id.to_s)
        expect(VirusScanJob).not_to receive(:perform_async).with(stuck_asset_with_file_missing.id.to_s)

        deleted_from_cloud_storage = []
        allow(Services.cloud_storage).to receive(:delete) do |asset|
          deleted_from_cloud_storage << asset.id
        end

        allow(Rails.logger).to receive(:info)
        expect(Rails.logger).to receive(:info)
          .with(/Enqueueing 2 unscanned assets for virus scanning/)
        expect(Rails.logger).to receive(:info)
          .with(/Removing 1 unscanned asset with its file missing/)

        sweep

        expect(stuck_asset_with_file_missing.reload).to be_deleted
        expect(stuck_asset.reload).not_to be_deleted
        expect(whitehall_stuck_asset.reload).not_to be_deleted
        expect(deleted_from_cloud_storage).to eq([stuck_asset_with_file_missing.id])
      end

      context "when setting custom batch size and age arguments" do
        let(:batch_size) { 1000 }
        let(:age_in_minutes) { 180 }

        it "honours them" do
          expect(VirusScanJob).not_to receive(:perform_async)

          sweep
        end
      end
    end

    context "when the batch size is invalid" do
      let(:batch_size) { 0 }

      it "raises" do
        expect { sweep }
          .to raise_error(ArgumentError, "Invalid batch size for requeueing unscanned assets: 0")
      end
    end

    context "when the age argument is invalid" do
      let(:age_in_minutes) { 0 }

      it "raises" do
        expect { sweep }
          .to raise_error(ArgumentError, "Invalid age in minutes for requeueing unscanned assets: 0")
      end
    end
  end

  describe "schedule configuration" do
    it "schedules the job to run periodically" do
      config = YAML.load_file(Rails.root.join("config/sidekiq.yml"))
      entry = config.dig(:scheduler, :schedule, "requeue_unscanned_assets")

      expect(entry).to include("class" => "RequeueUnscannedAssetsJob")
      expect(entry["cron"]).to eq("10 4 * * *")
    end
  end
end
