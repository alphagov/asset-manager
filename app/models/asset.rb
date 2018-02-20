require 'virus_scanner'
require 'services'

class Asset
  include Mongoid::Document
  include Mongoid::Paranoia
  include Mongoid::Timestamps

  field :state, type: String, default: 'unscanned'
  field :filename_history, type: Array, default: -> { [] }
  protected :filename_history=

  field :uuid, type: String, default: -> { SecureRandom.uuid }
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

  validates :file, presence: true, unless: :uploaded?

  validates :uuid, presence: true,
                   uniqueness: true,
                   format: {
                     with: /[a-zA-Z0-9]{8}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{4}-[a-zA-Z0-9]{12}/,
                     message: 'must match the format defined in rfc4122'
                   }

  mount_uploader :file, AssetUploader

  before_save :store_metadata, unless: :uploaded?
  after_save :schedule_virus_scan

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
      asset.remove_file!
    end
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
    '%x-%x' % [last_modified_from_file, file_stat.size]
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

  def set_size_from_etag
    self.size = size_from_etag
    save
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

  def size_from_etag
    etag.split('-').last.to_i(16)
  end
end
