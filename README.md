# Asset Manager

Manages uploaded assets (images, PDFs etc.) for applications in the GOV.UK Publishing stack.

The app receives uploaded files from publishing applications and returns the URLs that they will be made available at. Before an asset is available to the public, it is virus scanned. Once a file is found to be clean, Asset Manager serves it at the previously generated URL. Unscanned or Infected files return a 404 Not Found error. Deleted files return a 410 Gone response.

Scanning uses [ClamAV][clamav] and occurs asynchronously via [govuk_sidekiq][sidekiq].

## Technical Documentation

This is a Ruby on Rails app, and should follow [our Rails app conventions](https://docs.publishing.service.gov.uk/manual/conventions-for-rails-applications.html).

You can use the [GOV.UK Docker environment](https://github.com/alphagov/govuk-docker) to run the application and its tests with all the necessary dependencies. Follow [the usage instructions](https://github.com/alphagov/govuk-docker#usage) to get started.

**Use GOV.UK Docker to run any commands that follow.**

### Running the test suite

`bundle exec rspec`

### Assets on S3

All assets are uploaded to the S3 bucket via a separate `govuk_sidekiq` job triggered if virus scanning succeeds. Assets are currently still also saved to the NFS mount as per the original behaviour.

In non-production environments if the `AWS_S3_BUCKET_NAME` environment variable is not set, then a fake version of S3 (`S3Storage::Fake`) is used and the other `AWS_*` environment variables do not need to be set. In this case, files are saved to the local filesystem instead of S3 and are served via an instance of `Rack::Files` mounted on the appropriate route path prefix.

### Manuals and decisions

Check the [docs](docs/) directory for detailed instructions, including API documentation.

## Viewing the Sidekiq UI

We have access to the Sidekiq UI but because Asset Manager doesn't have a
frontend we have to use port forwarding to see it in our live environments.

You'll need to have access to our EKS clusters before you can follow these
instructions. There's [documentation here](https://docs.publishing.service.gov.uk/kubernetes/get-started/access-eks-cluster/#access-a-cluster-that-you-have-accessed-before) on how to do that. This means that
you'll need full production access before you can view the Sidekiq UI.

To view the UI run:

```
kubectl -n apps port-forward deployment/asset-manager 8080:8080
```

Navigate to:

```
localhost:8080/sidekiq
```

## Licence

[MIT License](LICENCE)

[clamav]:https://www.clamav.net/
[mongodb]:https://www.mongodb.org/
[mongoid]:https://github.com/mongodb/mongoid
[sidekiq]:https://github.com/alphagov/govuk_sidekiq
[govuk-puppet]:https://github.com/alphagov/govuk-puppet/blob/master/modules/clamav/manifests/package.pp
