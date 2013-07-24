# encoding: utf-8

class AssetUploader < CarrierWave::Uploader::Base

  storage :fog

  def store_dir
    id = model.id.to_s
    # We use chars 2-5 of the timestamp portion of the BSON id (see http://docs.mongodb.org/manual/core/object-id/)
    # to achieve a good distribution of directories
    "#{store_base_dir}/assets/#{id[2..3]}/#{id[4..5]}/#{id}"
  end

  def cache_dir
    "#{store_base_dir}/tmp"
  end

  # Split out the base storage dir so that it can be overridden in tests.
  def store_base_dir
    "#{ENV['GOVUK_APP_ROOT'] || Rails.root}/uploads"
  end

end
