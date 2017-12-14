class S3Configuration
  def initialize(env = ENV)
    @env = env
  end

  def bucket_name
    if Rails.env.production?
      @env.fetch('AWS_S3_BUCKET_NAME')
    else
      @env['AWS_S3_BUCKET_NAME']
    end
  end

  def configured?
    bucket_name.present?
  end

  def fake?
    !configured? && Rails.env.development?
  end
end
