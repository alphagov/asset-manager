class Asset
  include Mongoid::Document

  field :file, type: String

  validates :file, presence: true

  mount_uploader :file, AssetUploader
end
