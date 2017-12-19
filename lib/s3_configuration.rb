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
    if !configured? && Rails.env.production?
      raise 'S3 bucket name not set in production environment'
    end
  end

  def fake?
    !configured? && Rails.env.development?
  end
end
