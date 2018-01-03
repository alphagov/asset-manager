# Asset Manager

Manages uploaded assets (images, PDFs etc.) for applications in the GOV.UK Publishing stack.

## Technical Documentation

This is a small Rails application that receives uploaded files from publishing applications and returns the URLs that they will be made available at. Before an asset is available to the public, it is virus scanned. Once a file is found to be clean, Asset Manager serves it at the previously generated URL. Unscanned or Infected files return a 404 Not Found error.

Scanning uses [ClamAV][clamav] and occurs asynchronously via [govuk_sidekiq][sidekiq].

### Dependencies

- [MongoDB][mongodb] via [Mongoid][mongoid]
- [govuk_sidekiq][sidekiq]
- govuk_clamscan

Virus scanning expects `govuk_clamscan` to exist on the PATH, and to be symlinked to either `clamscan` or `clamdscan`, which are part of `clamav`. This is configured by [govuk-puppet][govuk-puppet].

### Running the application

`./startup.sh`

The application runs on port `3037` by default. Within the GDS VM it's exposed on http://asset-manager.dev.gov.uk.

It can also be run via bowl on the GDS dev VM:

```
bowl asset_manager
```

Newly uploaded assets return 404 until they've been scanned for viruses. Scanning for viruses is done asynchronously via govuk_sidekiq. Run the queue processor:

```
bundle exec sidekiq
```

### Assets on S3

All assets are uploaded to the S3 bucket via a separate `govuk_sidekiq` job triggered if virus scanning succeeds. Assets are currently still also saved to the NFS mount as per the original behaviour.

#### Standard AWS environment variables (required in production)

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `AWS_REGION`

#### Application-specific environment variables

* `AWS_S3_BUCKET_NAME` - name of bucket where assets are to be stored (required in production)

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

`POST /whitehall_assets` expects a single file uploaded via the `asset[file]` parameter and a path set in `asset[legacy_url_path]`. The latter tells Asset Manager the URL path at which the asset should be served. Note that this is intended as a transitional measure while we move Whitehall assets into Asset Manager. The idea is that eventually all asset URLs will be rationalised and consolidated and at that point Asset Manager will tell Whitehall the URL at which the asset will be served as it currently does for Mainstream assets. This endpoint also accepts two optional parameters, `asset[legacy_etag]` & `asset[legacy_last_modified]`. These are only intended for use when we move *existing* Whitehall assets into Asset Manager so that we can avoid wholesale cache invalidation. **Note** this endpoint should only be used from the Whitehall Admin app; not from any other publishing apps.

### API examples (development VM)

These examples assume you're using the [Development VM](https://github.com/alphagov/govuk-puppet/tree/master/development-vm).

#### Create an asset

```
# Create a temporary file
vagrant@development:$ echo `date` > tmp.txt

# Upload file to Asset Manager
vagrant@development:$ curl http://asset-manager.dev.gov.uk/assets --form "asset[file]=@tmp.txt"
{
  "_response_info":{"status":"created"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"unscanned"
}
```

#### Get asset info

```
# Before virus scanning
vagrant@development:$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{
  "_response_info":{"status":"ok"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"unscanned"
}

# After virus scanning
vagrant@development:$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{
  "_response_info":{"status":"ok"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"clean"
}
```

#### Get asset

```
# Before virus scanning
vagrant@development:$ curl http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
{
  "_response_info":{"status":"not found"}
}

# After virus scanning
vagrant@development:$ curl http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
Tue 18 Jul 2017 16:18:38 BST
```

#### Update asset

```
# Create a new tmp file
vagrant@development:$ echo `date` > tmp123.txt

# Update the file on asset-manager
vagrant@development:$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96 --request PUT --form "asset[file]=@tmp123.txt"
{
  "_response_info":{"status":"success"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp123.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp123.txt",
  "state":"unscanned"
}

# Request asset using original filename
vagrant@development:$ curl http://asset-manager.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
<html><body>You are being <a href="/media/597b098a759b743e0b759a96/tmp123.txt">redirected</a>.</body></html>

# Request asset using latest filename
vagrant@development:$ curl http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp123.txt
Tue 18 Jul 2017 17:06:41 BST
```

#### Delete asset

```
# Delete the asset
vagrant@development:$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96 \
  --request DELETE
{
  "_response_info":{"status":"success"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"clean"
}

# Confirm that it's been deleted
vagrant@development:$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{
  "_response_info":{"status":"not found"}
}
```

#### Restore asset

```
# This assumes the asset has been deleted
vagrant@development:$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96/restore \
  --request POST
{
  "_response_info":{"status":"success"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"clean"
}

# Confirm that it's been restored
vagrant@development:$ curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{
  "_response_info":{"status":"ok"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"clean"
}
```

#### Create a Whitehall asset

```
# Create a temporary file
vagrant@development:$ echo `date` > tmp.txt

# Upload file to Asset Manager
vagrant@development:$ curl http://asset-manager.dev.gov.uk/whitehall_assets --form "asset[file]=@tmp.txt" --form "asset[legacy_url_path]=/government/uploads/path/to/tmp.txt"
{
  "_response_info":{"status":"created"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/government/uploads/path/to/tmp.txt",
  "state":"unscanned"
}
```

### API examples (integration)

These examples assume you're running on a machine with access to the integration environment. You need to set two extra headers on all API requests:

* `Authorization: Bearer <bearer-token>`
* `Accept: application/json`

Note that the value of the bearer token is stored in `/etc/govuk/manuals-publisher/env.d/ASSET_MANAGER_BEARER_TOKEN`.

#### Create an asset

```
deploy@integration-backend-1:$ echo `date` > tmp.txt

deploy@integration-backend-1:$ cat tmp.txt
Wed Sep 20 14:42:54 UTC 2017

deploy@integration-backend-1:$ cat /etc/govuk/manuals-publisher/env.d/ASSET_MANAGER_BEARER_TOKEN
<bearer-token>

deploy@integration-backend-1:$ curl \
  -H"Authorization: Bearer <bearer-token>" \
  -H"Accept: application/json" \
  https://asset-manager.integration.publishing.service.gov.uk/assets \
  --form "asset[file]=@tmp.txt"

{
  "_response_info":{"status":"created"},
  "id":"https://asset-manager.integration.publishing.service.gov.uk/assets/59c282e2e5274a598a083a92",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"https://assets-origin.integration.publishing.service.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"unscanned"
}
```

#### Get asset info

```
deploy@integration-backend-1:$ curl \
  -H"Authorization: Bearer <bearer-token>" \
  -H"Accept: application/json" \
  https://asset-manager.integration.publishing.service.gov.uk/assets/59c282e2e5274a598a083a92
{
  "_response_info":{"status":"ok"},
  "id":"https://asset-manager.integration.publishing.service.gov.uk/assets/59c282e2e5274a598a083a92",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"https://assets-origin.integration.publishing.service.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"clean"
}
```

#### Get asset

Note that the extra request headers are not required for public asset URLs.

```
deploy@integration-backend-1:$ curl https://assets-origin.integration.publishing.service.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
Wed Sep 20 14:42:54 UTC 2017
```

## Licence

[MIT License](LICENCE)

[clamav]:https://www.clamav.net/
[mongodb]:https://www.mongodb.org/
[mongoid]:https://github.com/mongodb/mongoid
[sidekiq]:https://github.com/alphagov/govuk_sidekiq
[govuk-puppet]:https://github.com/alphagov/govuk-puppet/blob/master/modules/clamav/manifests/package.pp
