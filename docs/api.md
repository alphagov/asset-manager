# API

See the `AssetPresenter` class for the return format for the above API calls. Unless developing locally, all API requests must be authenticated with a token generated in the Signon application.

## Create an asset

`POST /assets` expects a single file uploaded via the `asset[file]` parameter. This creates the asset and schedules it for scanning.

```
# Create a temporary file
echo `date` > tmp.txt

# Upload file to Asset Manager
curl http://asset-manager.dev.gov.uk/assets --form "asset[file]=@tmp.txt"
{
  "_response_info":{"status":"created"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"unscanned"
}
```

## Get asset info

`GET /assets/:id` returns information about the requested asset, but not the asset itself.

```
# Before virus scanning
curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{
  "_response_info":{"status":"ok"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"unscanned"
}

# After virus scanning
curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{
  "_response_info":{"status":"ok"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"clean"
}
```

## Get asset

`GET /media/:id/:filename` serves the file to the user if it is marked as clean.

```
# Before virus scanning
curl http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
{
  "_response_info":{"status":"not found"}
}

# After virus scanning
curl http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
Tue 18 Jul 2017 16:18:38 BST
```

## Update asset

`PUT /assets/:id` expects a file in the same format, and replaces it at the provided ID.

```
# Create a new tmp file
echo `date` > tmp123.txt

# Update the file on asset-manager
curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96 --request PUT --form "asset[file]=@tmp123.txt"
{
  "_response_info":{"status":"success"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp123.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp123.txt",
  "state":"unscanned"
}

# Request asset using original filename
curl http://asset-manager.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt
<html><body>You are being <a href="/media/597b098a759b743e0b759a96/tmp123.txt">redirected</a>.</body></html>

# Request asset using latest filename
curl http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp123.txt
Tue 18 Jul 2017 17:06:41 BST
```

## Delete asset

`DELETE /assets/:id` marks the asset as having been deleted.

```
# Delete the asset
curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96 \
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
curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{
  "_response_info":{"status":"not found"}
}
```

## Restore asset

`POST /assets/:id/restore` restores a previously deleted asset.

```
# This assumes the asset has been deleted
curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96/restore \
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
curl http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96
{
  "_response_info":{"status":"ok"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/media/597b098a759b743e0b759a96/tmp.txt",
  "state":"clean"
}
```

## Create a Whitehall asset

`POST /whitehall_assets` expects a single file uploaded via the `asset[file]` parameter and a path set in `asset[legacy_url_path]`. The latter tells Asset Manager the URL path at which the asset should be served. Note that this is intended as a transitional measure while we move Whitehall assets into Asset Manager. The idea is that eventually all asset URLs will be rationalised and consolidated and at that point Asset Manager will tell Whitehall the URL at which the asset will be served as it currently does for Mainstream assets. This endpoint also accepts two optional parameters, `asset[legacy_etag]` & `asset[legacy_last_modified]`. These are only intended for use when we move *existing* Whitehall assets into Asset Manager so that we can avoid wholesale cache invalidation. **Note** this endpoint should only be used from the Whitehall Admin app; not from any other publishing apps.

```
# Create a temporary file
echo `date` > tmp.txt

# Upload file to Asset Manager
curl http://asset-manager.dev.gov.uk/whitehall_assets --form "asset[file]=@tmp.txt" --form "asset[legacy_url_path]=/government/uploads/path/to/tmp.txt"
{
  "_response_info":{"status":"created"},
  "id":"http://asset-manager.dev.gov.uk/assets/597b098a759b743e0b759a96",
  "name":"tmp.txt",
  "content_type":"text/plain",
  "file_url":"http://assets-origin.dev.gov.uk/government/uploads/path/to/tmp.txt",
  "state":"unscanned"
}
```
