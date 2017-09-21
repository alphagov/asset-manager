class WhitehallAsset < Asset
  field :legacy_url_path, type: String
  attr_readonly :legacy_url_path

  validates :legacy_url_path,
    uniqueness: {
      allow_blank: true
    },
    format: {
      with: %r{\A/government/uploads},
      allow_blank: true,
      message: 'must start with /government/uploads'
    }

  def public_url_path
    legacy_url_path
  end

  def mainstream?
    false
  end
end
