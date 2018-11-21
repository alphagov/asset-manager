require 'virus_scanner'
require 'services'

class Asset
  include Mongoid::Document
  include Mongoid::Timestamps

  index deleted_at: 1

  belongs_to :replacement, class_name: 'Asset', optional: true, index: true

  field :state, type: String, default: 'unscanned'
  field :filename_history, type: Array, default: -> { [] }
  protected :filename_history=

  field :uuid, type: String, default: -> { SecureRandom.uuid }
  index uuid: 1
  attr_readonly :uuid

  field :draft, type: Boolean, default: false
  field :redirect_url, type: String

  field :etag, type: String
  protected :etag=

  field :last_modified, type: Time
  protected :last_modified=

  field :md5_hexdigest, type: String
  protected :md5_hexdigest=

  field :size, type: Integer
  protected :size=

  field :access_limited, type: Array, default: []

  field :auth_bypass_ids, type: Array, default: []

  field :parent_document_url, type: String

  field :deleted_at, type: Time

  validates :file, presence: true, unless: :uploaded?

  validates :uuid, presence: true,
                   uniqueness: true,
                   format: {
                     with: /[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/,
                     message: 'must match the format defined in rfc4122'
                   }

  validate :check_specified_replacement_exists
  validate :prevent_transition_from_published_to_draft_if_replaced
  validate :ensure_parent_document_url_is_valid

  mount_uploader :file, AssetUploader

  before_save :store_metadata, unless: :uploaded?
  after_save :schedule_virus_scan
  after_save :update_indirect_replacements

  scope :deleted, -> { where(:deleted_at.ne => nil) }
  scope :undeleted, -> { where(deleted_at: nil) }

  state_machine :state, initial: :unscanned do
    event :scanned_clean do
      transition unscanned: :clean
    end

    after_transition to: :clean do |asset, _|
      SaveToCloudStorageWorker.perform_async(asset.id)
    end

    event :scanned_infected do
      transition unscanned: :infected
    end

    event :upload_success do
      transition clean: :uploaded
    end

    after_transition to: :uploaded do |asset, _|
      asset.save!
      asset.remove_file!
      FileUtils.rmdir(File.dirname(asset.file.path))
    end
  end

  def accessible_by?(user)
    return true unless draft?
    return true if access_limited.empty?

    access_limited.include?(user.uid)
  end

  def valid_auth_bypass_token?(token)
    payload, = JWT.decode(token,
                          Rails.application.secrets.jwt_auth_secret,
                          true,
                          algorithm: 'HS256')
    payload['sub'].present? && auth_bypass_ids.include?(payload['sub'])
  rescue JWT::DecodeError
    false
  end

  def public_url_path
    "/media/#{id}/#{filename}"
  end

  def mainstream?
    true
  end

  def file=(file)
    old_filename = filename
    super(file).tap {
      filename_history.push(old_filename) if old_filename
    }
    reset_state
  end

  def filename_valid?(filename_to_test)
    valid_filenames.include?(filename_to_test)
  end

  def filename
    file.file.try(:identifier)
  end

  def extension
    File.extname(filename).downcase.delete('.')
  end

  def content_type
    mime_type = Mime::Type.lookup_by_extension(extension)
    mime_type ? mime_type.to_s : AssetManager.default_content_type
  end

  def image?
    %w(jpg jpeg png gif).include?(extension)
  end

  def etag_from_file
    '%<mtime>x-%<size>x' % {
      mtime: last_modified_from_file,
      size: file_stat.size
    }
  end

  def last_modified_from_file
    file_stat.mtime
  end

  def md5_hexdigest_from_file
    @md5_hexdigest ||= Digest::MD5.hexdigest(file.file.read)
  end

  def size_from_file
    file_stat.size
  end

  def update_indirect_replacements
    return unless replacement.present?

    Asset.where(replacement_id: self.id).each do |asset|
      asset.replacement = replacement
      asset.save
    end
  end

  # Overrides Mongoid::Persistable::Destroyable#destroy
  # Updates a document with a deleted_at timestamp, this
  # can be used with 'deleted' and 'undeleted' scopes.
  #
  def destroy(_options = nil)
    update(deleted_at: Time.zone.now)
  end

  def restore
    update(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

protected

  def store_metadata
    self.etag = etag_from_file
    self.last_modified = last_modified_from_file
    self.md5_hexdigest = md5_hexdigest_from_file
    self.size = size_from_file
  end

  def valid_filenames
    filename_history + [filename]
  end

  def reset_state
    self.state = 'unscanned'
    @file_stat = nil
    @md5_hexdigest = nil
  end

  def schedule_virus_scan
    VirusScanWorker.perform_async(self.id) if self.unscanned?
  end

  def file_stat
    File.stat(file.path)
  end

  def check_specified_replacement_exists
    replacement = Asset.where(id: replacement_id)
    if replacement_id.present? && replacement.blank?
      errors.add(:replacement, 'not found')
    end
  end

  def prevent_transition_from_published_to_draft_if_replaced
    if changes[:draft] == [false, true]
      if replacement.present?
        errors.add(:draft, 'cannot be true, because already replaced')
      end
      if redirect_url.present?
        errors.add(:draft, 'cannot be true, because already redirected')
      end
    end
  end

  def ensure_parent_document_url_is_valid
    return unless parent_document_url.present?

    begin
      uri = Addressable::URI.parse(parent_document_url)
    rescue Addressable::URI::InvalidURIError
      uri = nil
    end

    unless uri && %w(http https).include?(uri.scheme)
      errors.add(:parent_document_url, 'must be an http(s) URL')
    end
  end
end
