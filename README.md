# Asset Manager

Manages uploaded assets (images, PDFs etc.) for applications in the GOV.UK Publishing stack.

## Technical Documentation

This is a small Rails application that receives uploaded files from publishing applications and returns the URLs that they will be made available at. Before an asset is available to the public, it is virus scanned. Once a file is found to be clean, Asset Manager serves it at the previously generated URL. Unscanned or Infected files return a 404 Not Found error.

Scanning uses [ClamAV][clamav] and occurs asynchronously via [govuk_sidekiq][sidekiq].

See the [docs](docs/) directory for more details, including API documentation.

### Assets on S3

All assets are uploaded to the S3 bucket via a separate `govuk_sidekiq` job triggered if virus scanning succeeds. Assets are currently still also saved to the NFS mount as per the original behaviour.

#### Fake S3

In non-production environments if the `AWS_S3_BUCKET_NAME` environment variable is not set, then a fake version of S3 (`S3Storage::Fake`) is used and the other `AWS_*` environment variables do not need to be set. In this case, files are saved to the local filesystem instead of S3 and are served via an instance of `Rack::File` mounted on the appropriate route path prefix.

### Testing

`bundle exec rspec`

## Licence

[MIT License](LICENCE)

[clamav]:https://www.clamav.net/
[mongodb]:https://www.mongodb.org/
[mongoid]:https://github.com/mongodb/mongoid
[sidekiq]:https://github.com/alphagov/govuk_sidekiq
[govuk-puppet]:https://github.com/alphagov/govuk-puppet/blob/master/modules/clamav/manifests/package.pp
