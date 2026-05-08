require "nokogiri"

class SvgDocument < Nokogiri::XML::SAX::Document
  class UnsafeSvg < StandardError; end

  UNSAFE_ELEMENTS = %w[script foreignobject iframe object].freeze

  def start_element(name, attrs = [])
    element_name = name.downcase

    if UNSAFE_ELEMENTS.include?(element_name)
      raise UnsafeSvg, "SVG: Unsafe element detected: <#{name}>"
    end

    attrs_hash = attrs.to_h

    attrs_hash.each do |attr_name, attr_value|
      attr_name_lower = attr_name.downcase

      if attr_name_lower.start_with?("on") # e.g. onload, onerror, onclick
        raise UnsafeSvg, "SVG: Unsafe event handler detected: '#{attr_name}' on <#{name}>"
      end

      if attr_value.to_s.strip.downcase.start_with?("javascript:") # e.g., href="javascript:alert(1)"
        raise UnsafeSvg, "SVG: Unsafe javascript URI detected in '#{attr_name}' attribute on <#{name}>"
      end
    end
  end
end

class SvgScanner
  def scan(file_path)
    svg_scanner = SvgDocument.new
    parser = Nokogiri::XML::SAX::Parser.new(svg_scanner)

    parser.parse(File.read(file_path))
    true
  end
end
