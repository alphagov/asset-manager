object @asset

node(:id) {|a| asset_url(a.id) }
node(:name) {|a| a.file.file.identifier }
node(:content_type) { |a| asset_mime_type(a).to_s }

