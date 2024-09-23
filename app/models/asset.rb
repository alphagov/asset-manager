require "virus_scanner"
require "services"

class Asset
  include Mongoid::Document
  include Mongoid::Timestamps

  # based on https://tools.ietf.org/html/rfc6838#section-4.2
  CONTENT_TYPE_FORMAT = %r{
    \A
    \w[\w!#&\-^_.+]+ # type
    / # separating slash
    \w[\w!#&\-^_.+]+ # subtype
    \Z
  }x

  index deleted_at: 1

  belongs_to :replacement, class_name: "Asset", optional: true, index: true

  field :state, type: String, default: "unscanned"
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

  field :content_type, type: String

  field :access_limited, type: Array, default: []

  field :access_limited_organisation_ids, type: Array, default: []

  field :auth_bypass_ids, type: Array, default: []

  field :parent_document_url, type: String

  field :deleted_at, type: Time

  validates :file, presence: true, if: :unscanned?

  validates :uuid,
            presence: true,
            uniqueness: true,
            format: {
              with: /[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/,
              message: "must match the format defined in rfc4122",
            }

  validates :content_type,
            format: {
              with: CONTENT_TYPE_FORMAT,
              message: "must match the format defined in rfc6838",
              allow_nil: true,
            }

  validate :check_specified_replacement_exists
  validate :prevent_transition_from_published_to_draft_if_replaced
  validate :ensure_parent_document_url_is_valid

  mount_uploader :file, AssetUploader

  before_save :store_metadata, unless: :uploaded?
  after_save :schedule_virus_scan
  after_save :update_indirect_replacements_on_publish
  after_save :backpropagate_replacement

  scope :deleted, -> { where(:deleted_at.ne => nil) }
  scope :undeleted, -> { where(deleted_at: nil) }

  state_machine :state, initial: :unscanned do
    around_transition do |asset, transition, block|
      Rails.logger.info("#{asset.id} - Asset#state_machine - event: #{transition.event}")
      block.call
    end

    event :scanned_clean do
      transition unscanned: :clean
    end

    after_transition to: :clean do |asset, _|
      SaveToCloudStorageWorker.perform_async(asset.id.to_s)
    end

    event :scanned_infected do
      transition unscanned: :infected
    end

    event :upload_success do
      transition clean: :uploaded
    end

    after_transition to: :uploaded do |asset, _|
      asset.save!
      DeleteAssetFileFromNfsJob.perform_in(5.minutes, asset.id.to_s)
    end
  end

  def accessible_by?(user)
    return true unless draft? && access_limited?

    access_limited.include?(user.uid) || access_limited_organisation_ids.include?(user.organisation_content_id)
  end

  def valid_auth_bypass_token?(auth_bypass_id)
    auth_bypass_ids.include?(auth_bypass_id)
  end

  def public_url_path
    "/media/#{id}/#{filename}"
  end

  def file=(file)
    old_filename = filename
    super(file).tap do
      filename_history.push(old_filename) if old_filename
    end
    reset_state
  end

  def filename_valid?(filename_to_test)
    valid_filenames.include?(filename_to_test)
  end

  def filename
    file.file.try(:identifier)
  end

  def extension
    File.extname(filename).downcase.delete(".")
  end

  def content_type_from_extension
    mime_type = Mime::Type.lookup_by_extension(extension)
    mime_type ? mime_type.to_s : AssetManager.default_content_type
  end

  def image?
    %w[jpg jpeg png gif].include?(extension)
  end

  def etag_from_file
    sprintf("%<mtime>x-%<size>x", mtime: last_modified_from_file, size: file_stat.size) if file_exists?
  end

  def last_modified_from_file
    file_stat.mtime if file_exists?
  end

  def md5_hexdigest_from_file
    @md5_hexdigest_from_file ||= Digest::MD5.hexdigest(file.file.read) if file_exists?
  end

  def size_from_file
    file_stat.size if file_exists?
  end

  def update_indirect_replacements_on_publish
    return unless saved_change_to_attribute(:draft) && !draft?

    Asset.where(replacement_id: id).each do |replaced_by_me|
      Asset.where(replacement_id: replaced_by_me.id).each do |indirectly_replaced_by_me|
        indirectly_replaced_by_me.replacement = self
        indirectly_replaced_by_me.save!
      end
    end
  end

  def backpropagate_replacement
    return if replacement.blank? || replacement.draft?

    Asset.where(replacement_id: id).each do |replaced_by_me|
      replaced_by_me.replacement = replacement
      replaced_by_me.save!
    end
  end

  # Overrides Mongoid::Persistable::Destroyable#destroy
  # Updates a document with a deleted_at timestamp, this
  # can be used with 'deleted' and 'undeleted' scopes.
  #
  def destroy(_options = nil)
    update!(deleted_at: Time.zone.now)
  end

  def restore
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def access_limited?
    access_limited.any? || access_limited_organisation_ids.any?
  end

  # Fixes carrierwave-mongoid gem which currently doesn't reload objects correctly
  # in rspec
  def reload(*)
    @_mounters = nil
    super
  end

  def initialize_dup(other)
    @_mounters = nil
    super
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
    self.state = "unscanned"
    @file_stat = nil
    @md5_hexdigest = nil
  end

  def schedule_virus_scan
    VirusScanJob.perform_async(id.to_s) if unscanned? && redirect_url.blank?
  end

  def file_exists?
    File.exist?(file.path)
  end

  def file_stat
    File.stat(file.path)
  end

  def check_specified_replacement_exists
    replacement = Asset.where(id: replacement_id)
    if replacement_id.present? && replacement.blank?
      errors.add(:replacement, "not found")
    end
  end

  def prevent_transition_from_published_to_draft_if_replaced
    if changes[:draft] == [false, true]
      if replacement.present?
        errors.add(:draft, "cannot be true, because already replaced")
      end
      if redirect_url.present?
        errors.add(:draft, "cannot be true, because already redirected")
      end
    end
  end

  def ensure_parent_document_url_is_valid
    return if parent_document_url.blank?

    begin
      uri = Addressable::URI.parse(parent_document_url)
    rescue Addressable::URI::InvalidURIError
      uri = nil
    end

    unless uri && %w[http https].include?(uri.scheme)
      errors.add(:parent_document_url, "must be an http(s) URL")
    end

    if uri && uri.host.start_with?("draft-origin") && !draft?
      errors.add(:parent_document_url, "must be a public GOV.UK URL")
    end
  end
end
