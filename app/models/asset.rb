require 'virus_scanner'

class Asset
  include Mongoid::Document

  field :file, type: String
  field :state, type: String, default: 'unscanned'

  validates :file, presence: true

  mount_uploader :file, AssetUploader

  state_machine :state, :initial => :unscanned do
    event :scanned_clean do
      transition :unscanned => :clean
    end

    event :scanned_infected do
      transition :unscanned => :infected
    end
  end

  def scan_for_viruses
    scanner = VirusScanner.new(self.file.current_path)
    if scanner.clean?
      self.scanned_clean
    else
      self.scanned_infected
    end
  end
end
