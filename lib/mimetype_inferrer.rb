require "open3"

# Simple wrapper around the Unix 'file' utility
#
# This expects AssetManager.govuk.file_utility_path to be an executable command
# that is compatible with 'file'.
#
# Note that this does not try to look inside encrypted or compressed files.
class MimetypeInferrer
  class Error < StandardError; end

  class MimetypeInferenceError < StandardError; end

  def infer(file_path)
    cmd = [
      AssetManager.govuk.file_utility_path,
      '--mime-type',
      '--brief',
      '-E', # Return a non-zero exit status on failure
      file_path.to_s
    ]

    out_str, status = Open3.capture2e(*cmd)
    out_str.strip!

    case status.exitstatus
    when 0
      out_str
    else
      # It might have failed to infer a mimetype,
      # or the file might be missing,
      # or we might lack permission to access it.
      raise MimetypeInferenceError, out_str
    end
  end
end
