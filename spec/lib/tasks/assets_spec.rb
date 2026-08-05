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

  describe "clear_legacy_access_limited" do
    let(:task) { Rake::Task["assets:clear_legacy_access_limited"] }

    before do
      task.reenable
    end

    it "clears legacy access_limited values without changing any other attributes" do
      asset = FactoryBot.create(:asset, access_limited: %w[user1 user2])
      asset.reload

      original_attributes = asset.attributes

      expect {
        task.invoke
      }.not_to(change { asset.reload.updated_at })

      expect(asset.reload.attributes).to eq(
        original_attributes.merge("access_limited" => []),
      )
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

  # rubocop:disable RSpec/AnyInstance
  context "when running a bulk fix" do
    let(:asset_id) { BSON::ObjectId("6592008029c8c3e4dc76256c") }
    let(:file) { Tempfile.new("csv_file") }
    let(:filepath) { file.path }

    before do
      task.reenable # without this, calling `invoke` does nothing after first test
      csv_file = <<~CSV
        6592008029c8c3e4dc76256c
      CSV
      file.write(csv_file)
      file.close
    end

    describe "assets:bulk_fix:fix_assets_and_draft_replacements" do
      let(:task) { Rake::Task["assets:bulk_fix:fix_assets_and_draft_replacements"] }

      describe "Skip processing" do
        it "skips the asset if asset is not found" do
          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - SKIPPED. No asset found.
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        end

        it "skips already processed replacement assets" do
          file.open
          csv_file = <<~CSV
            6592008029c8c3e4dc76256c
            6592008029c8c3e4dc76256d
          CSV
          file.write(csv_file)
          file.close

          replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil, replacement_id: nil)
          FactoryBot.create(:asset, id: "6592008029c8c3e4dc76256c", replacement_id: replacement.id)
          FactoryBot.create(:asset, id: "6592008029c8c3e4dc76256d", replacement_id: replacement.id)

          expected_output = <<~OUTPUT
            Asset ID: 6592008029c8c3e4dc76256c - OK. Draft replacement #{replacement.id} deleted and updated to false.
            Asset ID: 6592008029c8c3e4dc76256d - PROCESSED. Replacement #{replacement.id} already processed.
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        end

        it "skips already processed assets" do
          file.open
          csv_file = <<~CSV
            6592008029c8c3e4dc76256c
            6592008029c8c3e4dc76256d
          CSV
          file.write(csv_file)
          file.close

          replacement = FactoryBot.create(:asset, id: "6592008029c8c3e4dc76256d", draft: true, deleted_at: nil, replacement_id: nil)
          FactoryBot.create(:asset, id: "6592008029c8c3e4dc76256c", replacement_id: replacement.id)

          expected_output = <<~OUTPUT
            Asset ID: 6592008029c8c3e4dc76256c - OK. Draft replacement #{replacement.id} deleted and updated to false.
            Asset ID: 6592008029c8c3e4dc76256d - PROCESSED. Asset already processed.
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        end

        it "skips processing a line if it is marked as DONE" do
          file.open
          csv_file = <<~CSV
            6592008029c8c3e4dc76256c,DONE
            6592008029c8c3e4dc76256d
          CSV
          file.write(csv_file)
          file.close

          skipped_asset = FactoryBot.create(:asset, id: "6592008029c8c3e4dc76256c", draft: true, deleted_at: nil)
          asset = FactoryBot.create(:asset, id: "6592008029c8c3e4dc76256d", draft: false, deleted_at: nil)

          expected_output = <<~OUTPUT
            Asset ID: 6592008029c8c3e4dc76256d - OK. Asset has been deleted.
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
          expect(skipped_asset.reload.deleted_at).to be_nil
          expect(skipped_asset.reload.draft).to be true
          expect(asset.reload.deleted_at).not_to be_nil
          expect(asset.reload.draft).to be false
          expect(File.read(filepath)).to eq "6592008029c8c3e4dc76256c,DONE\n6592008029c8c3e4dc76256d,DONE\n"
        end

        it "skips the asset if asset is itself redirected (and not replaced by draft or itself a replacement)" do
          FactoryBot.create(:asset, id: asset_id, draft: false, redirect_url: "https://example.com")

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - SKIPPED. Asset is draft (false), deleted (false), replaced (false), or redirected (true).
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        end

        it "skips the asset, if the asset is further replaced (and not replaced by draft or itself a replacement)" do
          replacement = FactoryBot.create(:asset, draft: false)
          FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - SKIPPED. Asset is draft (false), deleted (false), replaced (true), or redirected (false).
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        end

        it "skips the asset, if the asset is already deleted (and is not itself a replacement)" do
          FactoryBot.create(:asset, id: asset_id, deleted_at: Time.zone.now)

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - SKIPPED. Asset is draft (false), deleted (true), replaced (false), or redirected (false).
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        end
      end

      describe "error scenarios" do
        it "rescues and logs if asset errors when saving" do
          asset = FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: nil)
          FactoryBot.create(:asset, replacement_id: asset.id)

          allow_any_instance_of(Asset).to receive(:save!).and_raise("failure!!")

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - ERROR. Asset failed to save. Error: failure!!.
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
          expect(asset.reload.draft).to be true
          expect(asset.reload.deleted_at).not_to be_nil
        end

        it "rescues and logs if asset errors when destroy" do
          asset = FactoryBot.create(:asset, id: asset_id, draft: false, deleted_at: nil, replacement_id: nil, redirect_url: nil)

          allow_any_instance_of(Asset).to receive(:destroy!).and_raise("failure!!")

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - ERROR. Asset failed to save. Error: failure!!.
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
          expect(asset.reload.deleted_at).to be_nil
        end

        it "rescues and logs if asset replacement errors when saving" do
          replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil)
          FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

          allow_any_instance_of(Asset).to receive(:save!).and_raise("failure!!")

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - ERROR. Asset replacement #{replacement.id} failed to save. Error: failure!!.
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
          expect(replacement.reload.draft).to be true
          expect(replacement.reload.deleted_at).not_to be_nil
        end

        it "rescues and logs if asset replacement errors when destroying" do
          replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil)
          FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

          allow_any_instance_of(Asset).to receive(:destroy!).and_raise("failure!!")

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - ERROR. Asset replacement #{replacement.id} failed to save. Error: failure!!.
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
          expect(replacement.reload.draft).to be true
          expect(replacement.reload.deleted_at).to be_nil
        end

        it "rescues and logs if asset fails validation when saving" do
          asset = FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: Time.zone.now)
          FactoryBot.create(:asset, replacement_id: asset.id)
          asset.state = "invalid"
          asset.save!(validate: false)

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - ERROR. Asset failed to save. Error: ["State is invalid"].
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
          expect(asset.reload.draft).to be true
        end

        it "rescues and logs if asset fails validation when destroying" do
          asset = FactoryBot.create(:asset, id: asset_id, draft: false, deleted_at: nil, replacement_id: nil, redirect_url: nil)
          asset.state = "invalid"
          asset.save!(validate: false)

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - ERROR. Asset failed to save. Error: ["State is invalid"].
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
          expect(asset.reload.deleted_at).to be_nil
        end

        it "rescues and logs if asset replacement fails validation when saving" do
          replacement = FactoryBot.create(:asset, draft: true, deleted_at: Time.zone.now)
          FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)
          replacement.state = "invalid"
          replacement.save!(validate: false)

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - ERROR. Asset replacement #{replacement.id} failed to save. Error: ["State is invalid"].
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
          expect(replacement.reload.draft).to be true
        end

        it "rescues and logs if asset replacement fails validation when destroying" do
          replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil)
          FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)
          replacement.state = "invalid"
          replacement.save!(validate: false)

          expected_output = <<~OUTPUT
            Asset ID: #{asset_id} - ERROR. Asset replacement #{replacement.id} failed to save. Error: ["State is invalid"].
          OUTPUT
          expect { task.invoke(filepath) }.to output(expected_output).to_stdout
          expect(replacement.reload.draft).to be true
          expect(replacement.reload.deleted_at).to be_nil
        end
      end

      it "only updates the draft state of the replacement if the asset replacement is already deleted" do
        replacement = FactoryBot.create(:asset, draft: true, deleted_at: Time.zone.now, replacement_id: nil)
        FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - OK. Draft replacement #{replacement.id} deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(replacement.reload.draft).to be false
      end

      it "deletes the asset replacement, updates the draft state, and turn draft parent_url to nil if the replacement is not deleted" do
        replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil, replacement_id: nil, parent_document_url: "https://draft-origin.publishing.service.gov.uk/example")
        FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

        expected_output = <<~OUTPUT
          Patched Parent URL: #{replacement.id}
          Asset ID: #{asset_id} - OK. Draft replacement #{replacement.id} deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(replacement.reload.deleted_at).not_to be_nil
        expect(replacement.reload.draft).to be false
        expect(replacement.reload.parent_document_url).to be_nil
      end

      it "deletes the asset replacement, updates the draft state, and leave live parent_url alone if the replacement is not deleted" do
        replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil, replacement_id: nil, parent_document_url: nil)
        FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - OK. Draft replacement #{replacement.id} deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(replacement.reload.deleted_at).not_to be_nil
        expect(replacement.reload.draft).to be false
        expect(replacement.reload.parent_document_url).to be_nil
      end

      it "deletes the asset replacement and fixes invalid upload state if the replacement is not deleted" do
        replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil)
        FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)
        replacement.state = "deleted"
        replacement.save!(validate: false)

        expected_output = <<~OUTPUT
          Patched state: #{replacement.id}
          Asset ID: #{asset_id} - OK. Draft replacement #{replacement.id} deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(replacement.reload.deleted_at).not_to be_nil
        expect(replacement.reload.draft).to be false
        expect(replacement.reload.state).to eq "uploaded"
      end

      it "deletes the asset replacement, updates the draft state, if the asset has further replacements and the replacement is in draft" do
        further_replacement = FactoryBot.create(:asset, draft: false)
        replacement = FactoryBot.create(:asset, draft: true, replacement_id: further_replacement.id)
        FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - OK. Draft replacement #{replacement.id} deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
      end

      it "only updates the draft state if the asset is already deleted (asset is a replacement)" do
        asset = FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: Time.zone.now)
        FactoryBot.create(:asset, replacement_id: asset.id)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - OK. Asset is a replacement. Asset deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(asset.reload.deleted_at).not_to be_nil
        expect(asset.reload.draft).to be false
      end

      it "deletes the asset, updates the draft state, and turn draft parent_url into nil if the asset is not deleted (asset is a replacement)" do
        asset = FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: nil, parent_document_url: "https://draft-origin.publishing.service.gov.uk/example")
        FactoryBot.create(:asset, replacement_id: asset.id)

        expected_output = <<~OUTPUT
          Patched Parent URL: #{asset_id}
          Asset ID: #{asset_id} - OK. Asset is a replacement. Asset deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(asset.reload.deleted_at).not_to be_nil
        expect(asset.reload.draft).to be false
        expect(asset.reload.parent_document_url).to be_nil
      end

      it "deletes the asset, updates the draft state, and leaves live parent_url alone if the asset is not deleted (asset is a replacement)" do
        asset = FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: nil, parent_document_url: nil)
        FactoryBot.create(:asset, replacement_id: asset.id)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - OK. Asset is a replacement. Asset deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(asset.reload.deleted_at).not_to be_nil
        expect(asset.reload.draft).to be false
        expect(asset.reload.parent_document_url).to be_nil
      end

      it "deletes the asset and fixes invalid upload state if the asset is not deleted (asset is a replacement)" do
        asset = FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: nil)
        FactoryBot.create(:asset, replacement_id: asset.id)
        asset.state = "deleted"
        asset.save!(validate: false)

        expected_output = <<~OUTPUT
          Patched state: #{asset_id}
          Asset ID: #{asset_id} - OK. Asset is a replacement. Asset deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(asset.reload.deleted_at).not_to be_nil
        expect(asset.reload.draft).to be false
        expect(asset.reload.state).to eq "uploaded"
      end

      it "catch-all case: it deletes the asset" do
        FactoryBot.create(:asset, id: asset_id, draft: false, deleted_at: nil, replacement_id: nil, redirect_url: nil)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - OK. Asset has been deleted.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
      end

      it "deletes but not update draft status of the asset if asset is itself in draft, not deleted, not redirected, not replaced" do
        asset = FactoryBot.create(:asset, id: asset_id, draft: true)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - OK. Asset has been deleted.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(asset.reload.draft).to be true
      end

      it "marks a line as 'done' in the CSV if line is processed" do
        FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: nil)
        task.invoke(filepath)
        expect(File.read(filepath)).to eq "6592008029c8c3e4dc76256c,DONE\n"
      end
    end
  end
  # rubocop:enable RSpec/AnyInstance
end
