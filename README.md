# Asset Manager

Manages uploaded assets (images, PDFs etc.) for applications in the GOV.UK Publishing stack.

## Technical Documentation

This is a small Rails application that receives uploaded files from publishing applications and returns the URLs that they will be made available at. Before an asset is available to the public, it is virus scanned. Once a file is found to be clean, Asset Manager serves it at the previously generated URL. Unscanned or Infected files return a 404 Not Found error.

Scanning uses [ClamAV][clamav] and occurs asynchronously via [Delayed Job][delayed_job].

### Dependencies

- [MongoDB][mongodb] via [Mongoid][mongoid]
- [Delayed Job][delayed_job]
- govuk_clamscan

Virus scanning expects `govuk_clamscan` to exist on the PATH,
and to be symlinked to either `clamscan` or `clamdscan`, which are
part of `clamav`. This is configured by [govuk-puppet][govuk-puppet].

### Running the application

`./startup.sh`

The application runs on port `3037` by default. Within the GDS VM it's exposed on http://asset-manager.dev.gov.uk.

It can also be run via bowl on the GDS dev VM:

```
bowl asset_manager
```

Newly uploaded assets return 404 until they've been scanned for viruses. Scanning for viruses is done asynchronously via Delayed Job. Run Delayed Job queue processor:

```
bundle exec rake jobs:work
```

### Assets on S3

This functionality is *very* experimental and should not be switched on in production until performance tests have been carried out to ensure there has been no degradation in performance.

As long as the S3 bucket is configured, all assets are uploaded to the S3 bucket via a separate `Delayed::Job` triggered if virus scanning succeeds. Assets are still saved to the NFS mount as per the original behaviour.

The following environment variables are only needed if you want to enable this functionality, i.e. they are all optional.

#### Standard AWS environment variables

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `AWS_REGION`

#### Application-specific environment variables

* `AWS_S3_BUCKET_NAME` - name of bucket where assets are to be stored
* `STREAM_ALL_ASSETS_FROM_S3` - causes *all* assets to be served from S3 via the app

#### Request parameter

Assets can be streamed from S3 even if `STREAM_ALL_ASSETS_FROM_S3` is not set by adding `stream_from_s3=true` as a request parameter key-value pair to the query string.

### Testing

`bundle exec rspec`

### API

`POST /assets` expects a single file uploaded via the `asset[file]` parameter. This creates the asset and schedules it for scanning.

`PUT /assets/:id` expects a file in the same format, and replaces it at the provided ID.

`GET /assets/:id` returns information about the requested asset, but not the asset itself.

See the `AssetPresenter` class for the return format for the above API calls. All API requests must be authenticated with a token generated in the Signon application.

`GET /media/:id/:filename` serves the file to the user if it is marked as clean.

## Licence

[MIT License](LICENCE)

[clamav]:https://www.clamav.net/
[mongodb]:https://www.mongodb.org/
[mongoid]:https://github.com/mongodb/mongoid
[delayed_job]:https://github.com/collectiveidea/delayed_job
[govuk-puppet]:https://github.com/alphagov/govuk-puppet/blob/master/modules/clamav/manifests/package.pp
