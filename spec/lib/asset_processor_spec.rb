require 'rails_helper'
require 'asset_processor'

RSpec.describe AssetProcessor do
  subject(:processor) { described_class.new(**args) }

  let(:args) { { output: output, report_progress_every: report_progress_every } }
  let(:output) { StringIO.new }
  let(:report_progress_every) { 1 }

  let!(:asset_1) { FactoryGirl.create(:asset) }
  let!(:asset_2) { FactoryGirl.create(:asset) }

  it 'iterates over all assets' do
    asset_ids = []
    processor.process_all_assets_with do |asset_id|
      asset_ids << asset_id
    end
    expect(asset_ids).to contain_exactly(asset_1.id.to_s, asset_2.id.to_s)
  end

  it 'reports progress for every asset' do
    processor.process_all_assets_with {}

    expect(output_lines[0]).to eq('1 of 2 (50%) assets')
    expect(output_lines[1]).to eq('2 of 2 (100%) assets')
    expect(output_lines[2]).to be_blank
    expect(output_lines[3]).to eq('Finished!')
  end

  context 'when report_progress_every option is set to 2' do
    let(:report_progress_every) { 2 }

    it 'only reports progress for every 2 assets' do
      processor.process_all_assets_with {}

      expect(output_lines[0]).to eq('2 of 2 (100%) assets')
      expect(output_lines[1]).to be_blank
      expect(output_lines[2]).to eq('Finished!')
    end
  end

  def output_lines
    @output_lines ||= begin
      output.rewind
      output.readlines.map(&:chomp)
    end
  end
end
