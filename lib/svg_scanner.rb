require 'nokogiri'

class UnsafeSvgError < StandardError; end

class SvgScanner < Nokogiri::XML::SAX::Document
  UNSAFE_ELEMENTS = ['script', 'foreignobject', 'iframe', 'object'].freeze

  def start_element(name, attrs = [])
    element_name = name.downcase

    if UNSAFE_ELEMENTS.include?(element_name)
      raise UnsafeSvgError, "Unsafe element detected: <#{name}>"
    end

    attrs_hash = attrs.to_h

    attrs_hash.each do |attr_name, attr_value|
      attr_name_lower = attr_name.downcase

      if attr_name_lower.start_with?('on') # e.g. onload, onerror, onclick
        raise UnsafeSvgError, "Unsafe event handler detected: '#{attr_name}' on <#{name}>"
      end

      if attr_value.to_s.strip.downcase.start_with?('javascript:') # e.g., href="javascript:alert(1)"
        raise UnsafeSvgError, "Unsafe javascript URI detected in '#{attr_name}' attribute on <#{name}>"
      end
    end
  end
end

def scan_svg(file_path)
  svg_scanner = SvgScanner.new
  parser = Nokogiri::XML::SAX::Parser.new(svg_scanner)

  begin
    parser.parse(File.read(file_path))

    puts "SVG scan complete: no forbidden elements or attributes found"
    return { safe: true, reason: nil }

  rescue UnsafeSvgError => e
    puts "SVG scan halted: #{e.message}"
    return { safe: false, reason: e.message }
  rescue Nokogiri::XML::SyntaxError => e
    puts "SVG scan halted: Malformed XML"
    return { safe: false, reason: "Malformed XML: #{e.message}" }
  end
end

# === Example Usage ===
# result = scan_svg('path/to/uploaded_image.svg')
#
# if !result[:safe]
#   puts "Rejected! Reason: #{result[:reason]}"
# end
