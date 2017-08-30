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

  field :access_limited, type: Boolean, default: false
  field :organisation_slug, type: String

  validates :file, presence: true
  validates :organisation_slug, presence: true, if: :access_limited?

  mount_uploader :file, AssetUploader

  after_save :schedule_virus_scan

  state_machine :state, initial: :unscanned do
    event :scanned_clean do
      transition any => :clean
    end

    after_transition to: :clean do |asset, _|
      asset.delay.save_to_cloud_storage
    end

    event :scanned_infected do
      transition any => :infected
    end
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
    if extension.present?
      Mime::Type.lookup_by_extension(extension).to_s
    else
      AssetManager.default_content_type
    end
  end

  def etag
    '%x-%x' % [last_modified, file_stat.size]
  end

  def last_modified
    file_stat.mtime
  end

  def scan_for_viruses
    scanner = VirusScanner.new(self.file.current_path)
    if scanner.clean?
      self.scanned_clean
    else
      Airbrake.notify_or_ignore(VirusScanner::InfectedFile.new, error_message: scanner.virus_info, params: { id: self.id, filename: self.filename })
      self.scanned_infected
    end
  rescue => e
    Airbrake.notify_or_ignore(e, params: { id: self.id, filename: self.filename })
    raise
  end

  def accessible_by?(user)
    return true unless access_limited?

    user && user.organisation_slug == self.organisation_slug
  end

  def save_to_cloud_storage
    Services.cloud_storage.save(self)
  rescue => e
    Airbrake.notify_or_ignore(e, params: { id: self.id, filename: self.filename })
    raise
  end

protected

  def valid_filenames
    filename_history + [filename]
  end

  def reset_state
    self.state = 'unscanned'
    @file_stat = nil
  end

  def schedule_virus_scan
    self.delay.scan_for_viruses if self.unscanned?
  end

  def file_stat
    @file_stat ||= File.stat(file.path)
  end
end
