# Asset Manager

Manages uploaded assets (images, PDFs etc.) for applications in the GOV.UK Publishing stack.

## Technical Documentation

This is a small Rails application that receives uploaded files from publishing applications and returns the URL it will be made available at. Before an asset is available to the public, it will be virus scanned. When a file is scanned and found to be clean, Asset Manager will serve it at the previously generated URL. Unscanned or Infected files return a 404 Not Found error.

Scanning uses [ClamAV][clamav] and occurs asynchronously via [Delayed Job][delayed_job].

### Dependencies

- [MongoDB][mongodb] via [Mongoid][mongoid]
- [Delayed Job][delayed_job]
- govuk_clamscan

Virus scanning expects `govuk_clamscan` to exist on the PATH,
and be a symlink to either `clamscan` or `clamdscan`, which are
part of `clamav`. This is configured by [govuk-puppet][govuk-puppet].

### Running the application

`./startup.sh`

The application runs on port `3037` by default. If you're using the GDS VM it's exposed on http://asset-manager.dev.gov.uk.

You can also run it via bowl on the GDS dev VM:

```
bowl asset_manager
```

Newly uploaded assets will return 404 until they've been scanned for viruses. Scanning for viruses is done asynchronously via Delayed Job. Run Delayed Job queue processor:

```
bundle exec rake jobs:work
```

### Testing

`bundle exec rspec`

### API

`POST /assets` expects a single file uploaded in the `asset[file]` parameter. This will create the asset and schedule it for scanning.

`POST /assets/:id` expects a file in the same format, and will replace the file at the provided ID.

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
