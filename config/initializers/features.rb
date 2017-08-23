AssetManager.proxy_all_asset_requests_to_s3_via_rails = ENV['PROXY_ALL_ASSET_REQUESTS_TO_S3_VIA_RAILS'].present?
AssetManager.proxy_all_asset_requests_to_s3_via_nginx = ENV['PROXY_ALL_ASSET_REQUESTS_TO_S3_VIA_NGINX'].present?
AssetManager.redirect_all_asset_requests_to_s3 = ENV['REDIRECT_ALL_ASSET_REQUESTS_TO_S3'].present?
