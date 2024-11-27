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

      it "skips the asset if asset is not found" do
        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - SKIPPED. No asset found.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
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

      it "deletes the asset replacement and updates the draft state if the replacement is not deleted" do
        replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil, replacement_id: nil)
        FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - OK. Draft replacement #{replacement.id} deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(replacement.reload.deleted_at).not_to be_nil
        expect(replacement.reload.draft).to be false
      end

      it "only updates the draft state if the asset is already deleted (asset is a replacement)" do
        asset = FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: Time.zone.now)
        FactoryBot.create(:asset, replacement_id: asset.id)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - is a replacement. Asset deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(asset.reload.deleted_at).not_to be_nil
        expect(asset.reload.draft).to be false
      end

      it "deletes the asset and updates the draft state if the asset is not deleted (asset is a replacement)" do
        asset = FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: nil)
        FactoryBot.create(:asset, replacement_id: asset.id)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - is a replacement. Asset deleted and updated to false.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(asset.reload.deleted_at).not_to be_nil
        expect(asset.reload.draft).to be false
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

      it "skips the asset if asset is itself in draft (and not replaced by draft or itself a replacement)" do
        FactoryBot.create(:asset, id: asset_id, draft: true)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - SKIPPED. Asset is draft (true), deleted (false), replaced (false), or redirected (false).
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

      it "catch-all case: it deletes the asset" do
        FactoryBot.create(:asset, id: asset_id, draft: false, deleted_at: nil, replacement_id: nil, redirect_url: nil)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - OK. Asset has been deleted.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
      end

      it "rescues and logs if asset fails to save" do
        asset = FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: nil)
        FactoryBot.create(:asset, replacement_id: asset.id)

        allow_any_instance_of(Asset).to receive(:save!).and_raise(StandardError)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - ERROR. Asset failed to save. Error: #{asset.errors.full_messages}.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(asset.reload.draft).to be true
        expect(asset.reload.deleted_at).not_to be_nil
      end

      it "rescues and logs if asset fails to destroy" do
        asset = FactoryBot.create(:asset, id: asset_id, draft: false, deleted_at: nil, replacement_id: nil, redirect_url: nil)

        allow_any_instance_of(Asset).to receive(:destroy!).and_raise(StandardError)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - ERROR. Asset failed to save. Error: #{asset.errors.full_messages}.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(asset.reload.deleted_at).to be_nil
      end

      it "rescues and logs if asset replacement fails to save" do
        replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil)
        FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

        allow_any_instance_of(Asset).to receive(:save!).and_raise(StandardError)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - ERROR. Asset replacement failed to save. Error: #{replacement.errors.full_messages}.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(replacement.reload.draft).to be true
        expect(replacement.reload.deleted_at).not_to be_nil
      end

      it "rescues and logs if asset replacement fails to destroy" do
        replacement = FactoryBot.create(:asset, draft: true, deleted_at: nil)
        FactoryBot.create(:asset, id: asset_id, replacement_id: replacement.id)

        allow_any_instance_of(Asset).to receive(:destroy!).and_raise(StandardError)

        expected_output = <<~OUTPUT
          Asset ID: #{asset_id} - ERROR. Asset replacement failed to save. Error: #{replacement.errors.full_messages}.
        OUTPUT
        expect { task.invoke(filepath) }.to output(expected_output).to_stdout
        expect(replacement.reload.draft).to be true
        expect(replacement.reload.deleted_at).to be_nil
      end

      it "marks a line as 'done' in the CSV if line is processed" do
        FactoryBot.create(:asset, id: asset_id, draft: true, deleted_at: nil)
        task.invoke(filepath)
        expect(File.read(filepath)).to eq "6592008029c8c3e4dc76256c,DONE\n"
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
    end
  end
  # rubocop:enable RSpec/AnyInstance
end
