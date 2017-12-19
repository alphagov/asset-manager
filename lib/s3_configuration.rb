class S3Configuration
  def self.build(env = ENV)
    config = new(env)
    config.check!
    config
  end

  def initialize(env = ENV)
    @env = env
  end

  def bucket_name
    @env['AWS_S3_BUCKET_NAME']
  end

  def configured?
    bucket_name.present?
  end

  def check!
    unless configured? || allow_fake?
      raise 'S3 bucket name not set'
    end
  end

  def fake?
    !configured? && allow_fake?
  end

  def allow_fake?
    !Rails.env.production? ||
      @env['ALLOW_FAKE_S3_IN_PRODUCTION_FOR_PUBLISHING_E2E_TESTS'].present?
  end
end
