# Migrating Asset Manager assets to S3

Our goal is to host GOV.UK assets on S3 instead of NFS.

The aim of this document is to provide a high level overview of our progress.


## Current status

We've modified Asset Manager to upload assets to S3 in addition to storing them on NFS.

We've modified the Asset Manager to allow us to optionally:

* Proxy asset requests to S3 via the Rails app
* Proxy asset requests to S3 via nginx
* Redirect asset requests to S3

We think that redirecting to assets on S3 is the ideal solution but it requires us to make a decision about the new URLs we'll need to create. We've decided to pursue the option of proxying asset requests to S3 via nginx so that we can defer making a decision about new URLs.


## Plan

| Task                                | Integration | Staging | Production |
| ----------------------------------- | ----------- | ------- | ---------- |
| Create IAM User                     | Y           | Y       | Y          |
| Create S3 Bucket                    | Y           | Y       | Y          |
| Upload assets to S3                 | Y           | Y       | Y          |
| Optionally proxy from Rails to S3   | Y           | Y       | Y          |
| Optionally proxy from nginx to S3   | Y           |         |            |
| Migrate existing assets             |             |         |            |
| Remove NFS                          |             |         |            |


## History

### Thu 17 Aug

* Assets can be proxied from S3 via nginx in integration.

### Thu 10 Aug

* Decided to revisit the idea of proxying requests via nginx to allow us to defer the decision about new asset URLs.

### Mon 7 Aug

* Assets can be proxied from S3 via the Rails app in all environments.

### Wed 2 Aug

* Assets are being uploaded to S3 (as well as being stored on NFS) in all environments.
