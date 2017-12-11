require 'govuk_configuration'

class FakeS3Configuration
  def initialize(env = ENV, govuk_config = GovukConfiguration.new)
    @env = env
    @govuk_config = govuk_config
  end

  def root
    Rails.root.join('fake-s3')
  end

  def path_prefix
    '/fake-s3'
  end

  def host
    @env['FAKE_S3_HOST'] || @govuk_config.app_host || 'http://localhost:3000'
  end
end
