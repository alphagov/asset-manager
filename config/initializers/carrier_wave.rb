directory = if Rails.env.test?
              Rails.root.join("tmp/test_uploads")
            elsif ENV["GOVUK_APP_ROOT"]
              "#{ENV['GOVUK_APP_ROOT']}/uploads"
            else
              Rails.root.join("uploads")
            end

AssetManager.carrier_wave_store_base_dir = directory
