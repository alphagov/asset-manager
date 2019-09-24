require "rails_helper"
require "asset_processor"

RSpec.describe AssetProcessor do
  subject(:processor) { described_class.new(**args) }

  let(:args) { { output: output, report_progress_every: report_progress_every } }
  let(:output) { StringIO.new }
  let(:report_progress_every) { 1 }

  let!(:asset_1) { FactoryBot.create(:asset) }
  let!(:asset_2) { FactoryBot.create(:asset) }

  it "iterates over all assets" do
    asset_ids = []
    processor.process_all_assets_with do |asset_id|
      asset_ids << asset_id
    end
    expect(asset_ids).to contain_exactly(asset_1.id.to_s, asset_2.id.to_s)
  end

  it "reports progress for every asset" do
    processor.process_all_assets_with {}

    expect(output_lines[0]).to eq("1 of 2 (50%) assets")
    expect(output_lines[1]).to eq("2 of 2 (100%) assets")
    expect(output_lines[2]).to be_blank
    expect(output_lines[3]).to eq("Finished!")
  end

  context "when report_progress_every option is set to 2" do
    let(:report_progress_every) { 2 }

    it "only reports progress for every 2 assets" do
      processor.process_all_assets_with {}

      expect(output_lines[0]).to eq("2 of 2 (100%) assets")
      expect(output_lines[1]).to be_blank
      expect(output_lines[2]).to eq("Finished!")
    end

    context "and number of assets is not a multiple of 2" do
      before do
        FactoryBot.create(:asset)
      end

      it "still reports 100% progress" do
        processor.process_all_assets_with {}

        expect(output_lines[0]).to eq("2 of 3 (67%) assets")
        expect(output_lines[1]).to eq("3 of 3 (100%) assets")
        expect(output_lines[2]).to be_blank
        expect(output_lines[3]).to eq("Finished!")
      end
    end
  end

  context "when scope is set to deleted assets" do
    let(:args) { { scope: scope, output: output } }
    let(:scope) { Asset.deleted }

    before do
      asset_1.destroy
    end

    it "iterates over all deleted assets" do
      asset_ids = []
      processor.process_all_assets_with do |asset_id|
        asset_ids << asset_id
      end
      expect(asset_ids).to contain_exactly(asset_1.id.to_s)
    end
  end

  def output_lines
    @output_lines ||= begin
      output.rewind
      output.readlines.map(&:chomp)
    end
  end
end
