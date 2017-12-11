class FakeS3Configuration
  def root
    Rails.root.join('fake-s3')
  end

  def path_prefix
    '/fake-s3'
  end
end
