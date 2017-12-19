class S3Configuration
  def self.build
    config = new
    config.check!
    config
  end

  def initialize(env = ENV)
    @env = env
  end

  def bucket_name
    if Rails.env.production? && !ENV['USE_FAKE_S3']
      @env.fetch('AWS_S3_BUCKET_NAME')
    else
      @env['AWS_S3_BUCKET_NAME']
    end
  end

  def configured?
    bucket_name.present?
  end

  alias_method :check!, :configured?

  def fake?
    !configured? && Rails.env.development?
  end
end
