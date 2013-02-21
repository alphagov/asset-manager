object @asset

node(:id) { |a| asset_url(a.id) }
node(:name) { |a| a.file.file.identifier }
node(:content_type) { |a| asset_mime_type(a).to_s }
node(:file_url) { |a|
  url_for(:controller => "media", :action => "download",
          :id => a.id, :filename => a.file.file.identifier,
          :only_path => false)
}
