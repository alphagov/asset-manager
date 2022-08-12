require "rails_helper"

RSpec.describe "asset tasks" do
  describe "assets:update_topical_event_legacy_url_paths" do
    let(:task) { Rake::Task["assets:update_topical_event_legacy_url_paths"] }

    before { task.reenable }

    def legacy_url(asset_name, model_name)
      "/government/uploads/system/uploads/#{model_name}/file/1234/#{asset_name}.jpeg"
    end

    it "updates any assets with legacy urls matching /classification_featuring_image_data to /topical_event_image_data" do
      classification_featuring_urls = (1..5).map { |i| legacy_url("asset-#{i}", "classification_featuring_image_data") }
      non_matching_url = legacy_url("asset-10", "not_a_classification_featuring_image_data")
      (classification_featuring_urls + [non_matching_url]).each { |url| FactoryBot.create(:whitehall_asset, legacy_url_path: url) }

      expect { task.invoke }.to output.to_stdout

      task.invoke

      topical_event_featuring_assets = WhitehallAsset.where(legacy_url_path: /\/government\/uploads\/system\/uploads\/topical_event_featuring_image_data/)
      expected_urls = (1..5).map { |i| legacy_url("asset-#{i}", "topical_event_featuring_image_data") }
      expect(topical_event_featuring_assets.pluck(:legacy_url_path)).to eq expected_urls
      expect(WhitehallAsset.where(legacy_url_path: /\/government\/uploads\/system\/uploads\/classification_featuring_image_data/).count).to eq 0
    end

    it "only changes the legacy url path of assets with urls including classification_featuring_image_data" do
      asset_name = "asset-1"
      asset = FactoryBot.create(:whitehall_asset, legacy_url_path: legacy_url(asset_name, "classification_featuring_image_data"), created_at: Time.zone.local(2022, 1, 1))

      expect { task.invoke }.to output.to_stdout

      task.invoke

      asset_after_update = WhitehallAsset.where(legacy_url_path: legacy_url(asset_name, "topical_event_featuring_image_data")).first
      ignored_keys = %w[legacy_url_path updated_at last_modified]
      expect(asset.attributes.except(*ignored_keys)).to eq asset_after_update.attributes.except(*ignored_keys)
    end
  end
end
