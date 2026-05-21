require "rails_helper"
require "mimetype_inferrer"

RSpec.describe MimetypeInferrer, type: :file_handler do
  describe "inferring the mimetype of a file" do
    subject(:inferrer) { described_class.new }

    let(:svg_file_path) { fixture_file_path("asset.svg") }
    let(:non_svg_file_path) { fixture_file_path("asset.png") }
    let(:non_existant_file_path) { fixture_file_path("none") }
    let(:svg_without_extension) { fixture_file_path("asset-svg-without-extension") }
    let(:svg_mime_type) { "image/svg+xml" }

    # asset-with-capitalised-extension.TXT
    # asset-with-unregistered-mimetype-extension.doc
    # asset-without-extension

    it "calls out to 'file'" do
      output = ""
      status = instance_double(Process::Status, exitstatus: 0)
      allow(Open3).to receive(:capture2e).and_return([output, status])
      expect(Open3).to receive(:capture2e).with("file", "--mime-type", "--brief", "-E", svg_file_path.to_s)

      inferrer.infer(svg_file_path)
    end

    context "when 'file' fails" do
      it "raises Error exception with the output message" do
        status = instance_double(Process::Status, exitstatus: 1)
        output = "ERROR: cannot stat `#{non_existant_file_path}' (No such file or directory)"
        expect {
          inferrer.infer(non_existant_file_path)
        }.to raise_error(MimetypeInferrer::MimetypeInferenceError, output)
      end
    end

    context "the file is an SVG" do
      it "returns the SVG mimetype" do
        expect(inferrer.infer(svg_file_path)).to eq(svg_mime_type)
      end
    end

    context "the file is an SVG without a filetype extension" do
      it "returns the SVG mimetype" do
        expect(inferrer.infer(svg_without_extension)).to eq(svg_mime_type)
      end
    end

    context "the file is not an SVG" do
      it "returns a non-SVG mimetype" do
        expect(inferrer.infer(non_svg_file_path)).not_to eq(svg_mime_type)
      end
    end
  end
end
