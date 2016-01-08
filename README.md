# Asset Manager (Mule)

This is an application to manage uploaded assets (images, PDFs etc.)
for various applications.

Initially, this will only be an API, and the asset serving mechanism,
but it may well develop an admin interface in time.

### Dependencies

- MongoDB
- Delayed Job
- govuk_clamscan

Virus scanning expects `govuk_clamscan` to exist on the PATH,
and be a symlink to either `clamscan` or `clamdscan`, which are
part of `clamav`.

### Development

To launch the application, run `./startup.sh` in the `asset_manager` directory on the VM.

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
