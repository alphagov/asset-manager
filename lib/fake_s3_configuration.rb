require 'govuk_configuration'

class FakeS3Configuration
  def initialize(govuk_config = GovukConfiguration.new)
    @govuk_config = govuk_config
  end

  def root
    Rails.root.join('fake-s3')
  end

  def path_prefix
    '/fake-s3'
  end

  def host
    @govuk_config.app_host || 'http://localhost:3000'
  end
end
