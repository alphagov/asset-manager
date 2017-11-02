class S3Storage
  NOT_CONFIGURED_ERROR_MESSAGE = 'AWS S3 bucket not correctly configured'.freeze

  class Null
    def save(*); end

    def presigned_url_for(*)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end

    def exists?(*)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end

    def never_replicated?(*)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end

    def add_metadata_to(*)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end

    def remove_metadata_from(*)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end

    def set_metadata_for(*)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end

    def metadata_for(*)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end
  end
end
