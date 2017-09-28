class WhitehallAsset < Asset
  field :legacy_url_path, type: String
  attr_readonly :legacy_url_path

  alias_method :legacy_etag=, :etag=

  validates :legacy_url_path,
    presence: true,
    uniqueness: true,
    format: {
      with: %r{\A/government/uploads},
      message: 'must start with /government/uploads'
    }

  def public_url_path
    legacy_url_path
  end

  def mainstream?
    false
  end
end
