class S3Storage
  NOT_CONFIGURED_ERROR_MESSAGE = 'AWS S3 bucket not correctly configured'.freeze

  class Null
    def save(_asset, _options = {}); end

    def presigned_url_for(_asset, _http_method: 'GET')
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end

    def exists?(_asset)
      raise NotConfiguredError.new(NOT_CONFIGURED_ERROR_MESSAGE)
    end
  end
end
