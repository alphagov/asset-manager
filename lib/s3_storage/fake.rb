class S3Storage
  class Fake
    def initialize(root_directory)
      @source_root = Pathname.new(AssetManager.carrier_wave_store_base_dir)
      @target_root = Pathname.new(root_directory)
    end

    def upload(asset, **_args)
      source_path = source_path_for(asset)
      target_path = target_path_for(asset)
      FileUtils.mkdir_p(File.dirname(target_path))
      File.write(target_path, File.read(source_path))
    end

    def delete(asset, **_args)
      target_path = target_path_for(asset)
      File.delete(target_path)
    end

    def presigned_url_for(asset, **_args)
      relative_path = relative_path_for(asset)
      url_path_prefix = Pathname.new(AssetManager.fake_s3.path_prefix)
      url_path = url_path_prefix.join(relative_path)
      "#{AssetManager.fake_s3.host}#{url_path}"
    end

    def exists?(asset)
      target_path = target_path_for(asset)
      File.exist?(target_path)
    end

    def never_replicated?(_asset)
      raise NotImplementedError
    end

    def replicated?(_asset)
      raise NotImplementedError
    end

    def metadata_for(_asset)
      raise NotImplementedError
    end

    def source_path_for(asset)
      Pathname.new(asset.file.path)
    end

    def target_path_for(asset)
      relative_path = relative_path_for(asset)
      @target_root.join(relative_path)
    end

    def relative_path_for(asset)
      source_path_for(asset).relative_path_from(@source_root)
    end

    def healthy?
      true
    end
  end
end
