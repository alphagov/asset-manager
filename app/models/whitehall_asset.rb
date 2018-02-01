class WhitehallAsset < Asset
  field :legacy_url_path, type: String
  index legacy_url_path: 1
  attr_readonly :legacy_url_path

  field :legacy_etag, type: String
  field :legacy_last_modified, type: Time

  validates :legacy_url_path,
    presence: true,
    uniqueness: {
      conditions: -> { where(deleted_at: nil) }
    },
    format: {
      with: %r{\A/government/uploads},
      message: 'must start with /government/uploads'
    }

  def self.from_params(path:, format: nil, path_prefix: nil)
    legacy_url_path = "/#{path_prefix}#{path}"
    legacy_url_path += ".#{format}" if format.present?
    find_by(legacy_url_path: legacy_url_path)
  end

  def etag
    legacy_etag || super
  end

  def last_modified
    legacy_last_modified || super
  end

  def public_url_path
    legacy_url_path
  end

  def mainstream?
    false
  end
end
