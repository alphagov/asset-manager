# Asset Manager

Manages uploaded assets (images, PDFs etc.) for applications in the GOV.UK Publishing stack.

## Technical Documentation

This is a small Rails application that receives uploaded files from publishing applications and returns the URLs that they will be made available at. Before an asset is available to the public, it is virus scanned. Once a file is found to be clean, Asset Manager serves it at the previously generated URL. Unscanned or Infected files return a 404 Not Found error.

Scanning uses [ClamAV][clamav] and occurs asynchronously via [govuk_sidekiq][sidekiq].

See the [docs](docs/) directory for more details, including API documentation.

### Dependencies

- [MongoDB][mongodb] via [Mongoid][mongoid]
- [govuk_sidekiq][sidekiq]
- govuk_clamscan

Virus scanning expects `govuk_clamscan` to exist on the PATH, and to be symlinked to either `clamscan` or `clamdscan`, which are part of `clamav`. This is configured by [govuk-puppet][govuk-puppet].

### Assets on S3

All assets are uploaded to the S3 bucket via a separate `govuk_sidekiq` job triggered if virus scanning succeeds. Assets are currently still also saved to the NFS mount as per the original behaviour.

#### Standard AWS environment variables (required in production)

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `AWS_REGION`

#### Application-specific environment variables

* `AWS_S3_BUCKET_NAME` - name of bucket where assets are to be stored (required in production)

#### Fake S3

In non-production environments if the `AWS_S3_BUCKET_NAME` environment variable is not set, then a fake version of S3 (`S3Storage::Fake`) is used and the other `AWS_*` environment variables do not need to be set. In this case, files are saved to the local filesystem instead of S3 and are served via an instance of `Rack::File` mounted on the appropriate route path prefix.

### Development

Previously, the Rails app received `X-Sendfile-Type` & `X-Accel-Mapping` request headers and set the `X-Accel-Redirect` response header which caused `Rack::Sendfile` not to send the asset file in the body of the response. Nginx would interpret the `X-Accel-Redirect` response header and serve the file directly from disk. When running the app standalone (i.e. without Nginx) the app would not receive the request headers mentioned above. This in turn caused `Rack::Sendfile` to send the asset file in the body of the response. Thus it was possible to use the app running standalone to serve asset requests.

However, now the app doesn't make use of `Rack::Sendfile` and instead *always* responds to asset requests by setting the `X-Accel-Redirect` response header and *not* sending the asset file in the response body. Nginx is configured to proxy the request to the URL supplied in `X-Accel-Redirect` response header on the development VM, but if you want to run the app standalone and you want to actually serve the asset file in the response body, you'll need something (e.g. Nginx) in front of the Rails app.

### Testing

`bundle exec rspec`

## Licence

[MIT License](LICENCE)

[clamav]:https://www.clamav.net/
[mongodb]:https://www.mongodb.org/
[mongoid]:https://github.com/mongodb/mongoid
[sidekiq]:https://github.com/alphagov/govuk_sidekiq
[govuk-puppet]:https://github.com/alphagov/govuk-puppet/blob/master/modules/clamav/manifests/package.pp
