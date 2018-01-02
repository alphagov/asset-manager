require 'rails_helper'
require 'cli'

RSpec.describe CLI, type: :model do
  subject(:cli) { described_class.new(output, kernel) }

  let(:output) { StringIO.new }
  let(:kernel) { class_double('Kernel') }
  let(:path) { fixture_file_path('asset.png') }

  describe '#create_asset' do
    context 'when called with path to file' do
      let(:args) { [path] }

      it 'creates an asset' do
        expect { cli.create_asset(*args) }.to change { Asset.count }.by 1
      end

      it 'reports that asset was saved' do
        cli.create_asset(*args)

        output.rewind
        expect(output.read).to match(/^saved/i)
      end

      context 'when saving asset fails due to validation errors' do
        let(:invalid_asset) { Asset.new }

        before do
          allow(Asset).to receive(:new).and_return(invalid_asset)
        end

        it 'does not create an asset' do
          expect { cli.create_asset(*args) }.to change { Asset.count }.by 0
        end

        it 'reports that asset was not saved' do
          cli.create_asset(*args)

          output.rewind
          expect(output.read).to match(/^not saved/i)
        end
      end
    end

    context 'when called with no arguments' do
      let(:args) { [] }

      before do
        allow(kernel).to receive(:abort).and_raise('abort-error')
      end

      it 'aborts execution' do
        expect(kernel).to receive(:abort)

        cli.create_asset(*args) rescue nil
      end

      it 'prints usage instructions' do
        cli.create_asset(*args) rescue nil

        output.rewind
        expect(output.read).to match(/provide a filename/i)
      end
    end
  end
end
