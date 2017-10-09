class WhitehallAsset < Asset
  field :legacy_url_path, type: String
  attr_readonly :legacy_url_path

  field :legacy_etag, type: String
  field :legacy_last_modified, type: Time

  validates :legacy_url_path,
    presence: true,
    uniqueness: true,
    format: {
      with: %r{\A/government/uploads},
      message: 'must start with /government/uploads'
    }

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
