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
end
