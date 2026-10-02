require "rails_helper"
require "rake"

RSpec.describe "assets.rake" do
  before do
    AssetManager::Application.load_tasks if Rake::Task.tasks.empty?
  end

  describe "get_id_by_legacy_url_path" do
    before do
      task.reenable # without this, calling `invoke` does nothing after first test
    end

    let(:task) { Rake::Task["assets:get_id_by_legacy_url_path"] }

    it "returns ID of asset by its legacy URL path" do
      id = "abc123def456ghi789"
      legacy_url_path = "/government/uploads/system/uploads/attachment_data/file/1234/document.pdf"
      FactoryBot.create(:whitehall_asset, id:, legacy_url_path:)

      expected_output = <<~OUTPUT
        Asset ID for #{legacy_url_path} is #{id}.
      OUTPUT

      expect { task.invoke(legacy_url_path) }.to output(expected_output).to_stdout
    end

    it "raises exception if no asset found" do
      expect { task.invoke("foo") }.to raise_error(Mongoid::Errors::DocumentNotFound)
    end
  end

  describe "assets:bulk_scan_svgs" do
    let(:task) { Rake::Task["assets:bulk_scan_svgs"] }
    let(:sidekiq_queue) { instance_double(Sidekiq::Queue) }
    let(:queue_empty) { true }

    before do
      task.reenable

      allow(Sidekiq::Queue)
        .to receive(:new)
        .with("batch")
        .and_return(sidekiq_queue)
      allow(sidekiq_queue).to receive(:any?).and_return(!queue_empty)
    end

    context "when there are no in-scope assets to scan" do
      before do
        FactoryBot.create(:asset) # not uploaded
        FactoryBot.create(:uploaded_asset, deleted_at: Time.zone.now) # deleted
        FactoryBot.create(
          :uploaded_asset,
          redirect_url: "https://www.gov.uk/somewhere",
        ) # redirected
        FactoryBot.create(:uploaded_svg_asset) # scanned
        FactoryBot.create(:uploaded_asset).set(mime_type: "application/pdf") # wrong MIME type
      end

      it "raises an error without enqueuing any SVG scan" do
        expect(SvgScanBatchJob).not_to receive(:perform_async)

        expect { task.invoke("10") }
          .to raise_error("No assets found to enqueue for bulk SVG scanning")
      end
    end

    context "when there are in-scope assets to scan" do
      let!(:nil_mime_type_asset) { FactoryBot.create(:uploaded_asset).set(mime_type: nil) }
      let!(:unscanned_svg_asset) { FactoryBot.create(:uploaded_svg_asset).set(svg_scan_state: nil) }

      it "enqueues the assets for scanning" do
        expect(SvgScanBatchJob).to receive(:perform_async).with(nil_mime_type_asset.id.to_s)
        expect(SvgScanBatchJob).to receive(:perform_async).with(unscanned_svg_asset.id.to_s)

        task.invoke("10")
      end

      it "logs a info message" do
        allow(Rails.logger).to receive(:info)
        expect(Rails.logger)
          .to receive(:info)
          .with("Enqueuing up to 10 assets for bulk SVG scanning")

        task.invoke("10")
      end

      context "but the batch size is smaller than the in-scope asset count" do
        it "only enqueues assets up to the batch size" do
          expect(SvgScanBatchJob).to receive(:perform_async).once

          task.invoke("1")
        end
      end

      context "but the batch size is missing" do
        it "raises an error" do
          expect { task.invoke }
            .to raise_error(ArgumentError, "Invalid batch size for bulk SVG scanning: nil")
        end
      end

      context "but the batch size is zero" do
        it "raises an error" do
          expect { task.invoke("0") }
            .to raise_error(ArgumentError, "Invalid batch size for bulk SVG scanning: 0")
        end
      end

      context "but there are jobs in the batch queue" do
        let(:queue_empty) { false }

        it "does not enqueue any SVG scan" do
          expect(SvgScanBatchJob).not_to receive(:perform_async)

          task.invoke("10")
        end

        it "logs a message" do
          allow(Rails.logger).to receive(:info)
          expect(Rails.logger)
            .to receive(:info)
            .with(
              "Not enqueuing assets for bulk SVG scanning: previous batch still in progress",
            )

          task.invoke("10")
        end
      end
    end
  end
end
