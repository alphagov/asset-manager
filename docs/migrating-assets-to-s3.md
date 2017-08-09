# Migrating Asset Manager assets to S3

Our goal is to host GOV.UK assets on S3 instead of NFS.

The aim of this document is to provide a high level overview of our progress.


## Current status

We've modified Asset Manager to upload assets to S3 in addition to storing them on NFS.

We've tested the performance of proxying requests from Asset Manager to S3 but it's not good enough.

We now want to try redirecting requests from Asset Manager to S3. We have code in Asset Manager to support this but we need objects within our assets bucket to be publicly readable in order for us to test it.


## Plan

| Task                                | Integration | Staging | Production |
| ----------------------------------- | ----------- | ------- | ---------- |
| Create IAM User                     | Y           | Y       | Y          |
| Create S3 Bucket                    | Y           | Y       | Y          |
| Upload assets to S3                 | Y           | Y       | Y          |
| Optionally proxy to assets on S3    | Y           | Y       | Y          |
| Public-read on S3 bucket            |             |         |            |
| Optionally redirect to assets on S3 |             |         |            |
| S3 access logging                   |             |         |            |
| S3 CNAME                            |             |         |            |
| S3 CDN                              | NA          |         |            |
| Migrate existing assets             |             |         |            |
| Redirect to assets on S3            |             |         |            |
| Remove NFS                          |             |         |            |


## History

### Mon 7 Aug

* Assets can be proxied from S3 in all environments.

### Wed 2 Aug

* Assets are being uploaded to S3 (as well as being stored on NFS) in all environments.
