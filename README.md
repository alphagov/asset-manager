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

See the ["Migrating Asset Manager assets to S3" document](docs/migrating-assets-to-s3.md) for an overview of this project.

This functionality is *very* experimental and should not be switched on in production until performance tests have been carried out to ensure there has been no degradation in performance.

As long as the S3 bucket is configured, all assets are uploaded to the S3 bucket via a separate `Delayed::Job` triggered if virus scanning succeeds. Assets are still saved to the NFS mount as per the original behaviour.

The following environment variables are only needed if you want to enable this functionality, i.e. they are all optional.

#### Standard AWS environment variables

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `AWS_REGION`

#### Application-specific environment variables

* `AWS_S3_BUCKET_NAME` - name of bucket where assets are to be stored
* `PROXY_ALL_ASSET_REQUESTS_TO_S3_VIA_RAILS` - causes *all* asset requests to be proxied to S3 via the Rails app
* `REDIRECT_ALL_ASSET_REQUESTS_TO_S3` - causes *all* asset requests to be redirected to S3
* `AWS_S3_USE_VIRTUAL_HOST` - generate URLs for virtual host (requires CNAME setup for bucket)

#### Request parameters

* Asset requests can be proxied to S3 via the Rails app even if `PROXY_ALL_ASSET_REQUESTS_TO_S3_VIA_RAILS` is not set by adding `proxy_to_s3_via_rails=true` as a request parameter key-value pair to the query string.
* Asset requests can be redirected to S3 even if `REDIRECT_ALL_ASSET_REQUESTS_TO_S3` is not set by adding `redirect_to_s3=true` as a request parameter key-value pair to the query string.

### Testing

`bundle exec rspec`

### API

`POST /assets` expects a single file uploaded via the `asset[file]` parameter. This creates the asset and schedules it for scanning.

`PUT /assets/:id` expects a file in the same format, and replaces it at the provided ID.

`GET /assets/:id` returns information about the requested asset, but not the asset itself.

`DELETE /assets/:id` marks the asset as having been deleted.

`POST /assets/:id/restore` restores a previously deleted asset.

See the `AssetPresenter` class for the return format for the above API calls. All API requests must be authenticated with a token generated in the Signon application.

`GET /media/:id/:filename` serves the file to the user if it is marked as clean.

### API examples

__NOTE.__ These examples assume you're using the [Development VM](https://github.com/alphagov/govuk-puppet/tree/master/development-vm).

#### Create an asset

```
# Create a temporary file
$ echo `date` > tmp.txt

# Upload file to Asset Manager
$ curl http://asset-manager.dev.gov.uk/assets --form "asset[file]=@tmp.txt"
{"_response_info":{"status":"created"},"id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96","name":"tmp.txt","content_type":"text/plain","file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt","state":"unscanned"}
```

#### Get asset info

```
# Before virus scanning
$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{"_response_info":{"status":"ok"},"id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96","name":"tmp.txt","content_type":"text/plain","file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt","state":"unscanned"}

# After virus scanning
$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{"_response_info":{"status":"ok"},"id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96","name":"tmp.txt","content_type":"text/plain","file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt","state":"clean"}
```

#### Get asset

```
# Before virus scanning
$ curl http://asset-manager.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
{"_response_info":{"status":"not found"}}

# After virus scanning
$ curl http://asset-manager.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
Tue 18 Jul 2017 16:18:38 BST
```

#### Update asset

```
# Create a new tmp file
$ echo `date` > tmp123.txt

# Update the file on asset-manager
$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96 --request PUT --form "asset[file]=@tmp123.txt"
{"_response_info":{"status":"success"},"id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96","name":"tmp123.txt","content_type":"text/plain","file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp123.txt","state":"unscanned"}

# Request asset using original filename
$ curl http://asset-manager.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
<html><body>You are being <a href="/media/597b098a759b743e0b759a96/tmp123.txt">redirected</a>.</body></html>

# Request asset using latest filename
$ curl http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp123.txt
Tue 18 Jul 2017 17:06:41 BST
```

#### Delete asset

```
# Delete the asset
$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96 \
  --request DELETE
{"_response_info":{"status":"success"},"id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96","name":"tmp.txt","content_type":"text/plain","file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt","state":"clean"}

# Confirm that it's been deleted
$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{"_response_info":{"status":"not found"}}
```

#### Restore asset

```
# This assumes the asset has been deleted
$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96/restore \
  --request POST
{"_response_info":{"status":"success"},"id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96","name":"tmp.txt","content_type":"text/plain","file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt","state":"clean"}

# Confirm that it's been restored
$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{"_response_info":{"status":"ok"},"id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96","name":"tmp.txt","content_type":"text/plain","file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt","state":"clean"}
```

## Licence

[MIT License](LICENCE)

[clamav]:https://www.clamav.net/
[mongodb]:https://www.mongodb.org/
[mongoid]:https://github.com/mongodb/mongoid
[delayed_job]:https://github.com/collectiveidea/delayed_job
[govuk-puppet]:https://github.com/alphagov/govuk-puppet/blob/master/modules/clamav/manifests/package.pp
