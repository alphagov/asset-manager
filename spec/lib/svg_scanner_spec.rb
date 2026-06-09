require "rails_helper"
require "svg_scanner"

RSpec.describe SvgScanner, type: :file_handler do
  describe "scanning an SVG file" do
    subject(:scanner) { described_class.new }

    let(:safe_file_path) { fixture_file_path("asset-safe.svg") }
    let(:unsafe_element_file_path) { fixture_file_path("asset-unsafe-element.svg") }
    let(:unsafe_event_handler_file_path) { fixture_file_path("asset-unsafe-event-handler.svg") }
    let(:unsafe_uri_file_path) { fixture_file_path("asset-unsafe-uri.svg") }

    it "calls out to Nokogiri" do
      nokogiri_parser = instance_double(Nokogiri::XML::SAX::Parser)
      allow(Nokogiri::XML::SAX::Parser).to receive(:new).and_return(nokogiri_parser)
      allow(nokogiri_parser).to receive(:parse_io).with(an_object_having_attributes(path: safe_file_path))

      expect(nokogiri_parser).to receive(:parse_io)

      scanner.scan(safe_file_path)
    end

    context "when SVG is safe" do
      it "returns true" do
        expect(scanner.scan(safe_file_path)).to be true
      end
    end

    context "when SVG contains an unsafe element" do
      it "raises a relevant error" do
        expect {
          scanner.scan(unsafe_element_file_path)
        }.to raise_error(
          SvgDocument::UnsafeSvg, "SVG: Unsafe element detected: <script>"
        )
      end
    end

    context "when SVG contains an unsafe event handler" do
      it "raises a relevant error" do
        expect {
          scanner.scan(unsafe_event_handler_file_path)
        }.to raise_error(
          SvgDocument::UnsafeSvg, "SVG: Unsafe event handler detected: 'onload' on <svg>"
        )
      end
    end

    context "when SVG contains an unsafe URI" do
      it "raises a relevant error" do
        expect {
          scanner.scan(unsafe_uri_file_path)
        }.to raise_error(
          SvgDocument::UnsafeSvg, "SVG: Unsafe javascript URI detected in 'href' attribute on <a>"
        )
      end
    end
  end
end
