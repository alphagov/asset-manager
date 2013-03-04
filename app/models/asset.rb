class Asset
  include Mongoid::Document
  include Draper::Decoratable # Necessary becasue Draper isn't auto-included in mongoid 2

  field :file, type: String

  validates :file, presence: true

  mount_uploader :file, AssetUploader
end
