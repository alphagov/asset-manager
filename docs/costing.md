# Estimated cost of AWS storage

To store all of the [current assets](existing_assets.md) in Asset Manager and Whitehall would require ~670 GB. S3 storage is currently priced at [$0.023/GB/month on S3](https://aws.amazon.com/s3/pricing/) which equates to ~$15/month.

Amazon also offers an [Elastic File System (EFS)](https://aws.amazon.com/efs/) in the [Ireland and Frankfurt](https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/) availability zones. It appears to have the advantage over EBS in that the volumes scale automatically with the data that is added. As it can be mounted as a file-system to an EC2 instance it potentially offers an alternative for Asset Manager that would require smaller changes to the existing AM codebase (in that the mounted EFS system would appear to the asset manager application as a file system like the current NFS model).

EFS is more expensive than S3, [currently priced](https://aws.amazon.com/efs/pricing/) at $0.33/GB/month or ~$221/month for ~670GB.

The cost of serving the assets has not currently been calculated.
