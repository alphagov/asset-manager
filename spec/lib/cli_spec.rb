require "rails_helper"
require "cli"

RSpec.describe CLI, type: :model do
  subject(:cli) { described_class.new(output, kernel) }

  let(:output) { StringIO.new }
  let(:kernel) { class_double(Kernel) }
  let(:path) { fixture_file_path("asset.png") }

  describe "#create_asset" do
    context "when called with path to file" do
      let(:args) { [path] }

      it "creates an asset" do
        expect { cli.create_asset(*args) }.to change(Asset, :count).by 1
      end

      it "reports that asset was saved" do
        cli.create_asset(*args)

        output.rewind
        expect(output.read).to match(/^saved/i)
      end

      context "when saving asset fails due to validation errors" do
        let(:invalid_asset) { Asset.new }

        before do
          allow(Asset).to receive(:new).and_return(invalid_asset)
        end

        it "does not create an asset" do
          expect { cli.create_asset(*args) }.not_to change(Asset, :count)
        end

        it "reports that asset was not saved" do
          cli.create_asset(*args)

          output.rewind
          expect(output.read).to match(/^not saved/i)
        end
      end
    end

    context "when called with no arguments" do
      let(:args) { [] }

      before do
        allow(kernel).to receive(:abort).and_raise("abort-error")
      end

      it "aborts execution" do
        expect(kernel).to receive(:abort)

        begin
          cli.create_asset(*args)
        rescue StandardError
          nil
        end
      end

      it "prints usage instructions" do
        begin
          cli.create_asset(*args)
        rescue StandardError
          nil
        end

        output.rewind
        expect(output.read).to match(/provide a filename/i)
      end
    end
  end

  describe "#update_asset" do
    let(:asset) { FactoryBot.create(:uploaded_asset) }
    let(:new_path) { fixture_file_path("asset2.jpg") }

    context "when called with ID of existing asset and path to new file" do
      let(:args) { [asset.id, new_path] }

      it "updates existing asset" do
        cli.update_asset(*args)

        expect(asset.reload.file.file.identifier).to eq("asset2.jpg")
      end

      it "reports that asset was saved" do
        cli.update_asset(*args)

        output.rewind
        expect(output.read).to match(/^updated/i)
      end

      context "when saving asset fails due to validation errors" do
        let(:invalid_asset) { Asset.new }

        before do
          allow(Asset).to receive(:find).and_return(invalid_asset)
          allow(invalid_asset).to receive(:save).and_return(false)
        end

        it "does not update existing asset" do
          cli.update_asset(*args)

          expect(asset.reload.file.file.identifier).to eq("asset.png")
        end

        it "reports that asset was not updated" do
          cli.update_asset(*args)

          output.rewind
          expect(output.read).to match(/^not updated/i)
        end
      end
    end

    context "when called with ID of existing asset but no path to new file" do
      let(:args) { [asset.id] }

      before do
        allow(kernel).to receive(:abort).and_raise("abort-error")
      end

      it "aborts execution" do
        expect(kernel).to receive(:abort)

        begin
          cli.update_asset(*args)
        rescue StandardError
          nil
        end
      end

      it "prints usage instructions" do
        begin
          cli.update_asset(*args)
        rescue StandardError
          nil
        end

        output.rewind
        expect(output.read).to match(/provide a filename/i)
      end
    end

    context "when called with no arguments" do
      let(:args) { [] }

      before do
        allow(kernel).to receive(:abort).and_raise("abort-error")
      end

      it "aborts execution" do
        expect(kernel).to receive(:abort)

        begin
          cli.update_asset(*args)
        rescue StandardError
          nil
        end
      end

      it "prints usage instructions" do
        begin
          cli.update_asset(*args)
        rescue StandardError
          nil
        end

        output.rewind
        expect(output.read).to match(/provide the asset id/i)
      end
    end
  end
end
