# Local virus scanning with ClamAV

Per the main Asset Manager README, we use [ClamAV][] to scan uploaded assets for
viruses before they are made available to the public.

## When might you run a local scan?

One reason you might want to run a scan locally is if an error like
`Heuristics.Limits.Exceeded.MaxFiles FOUND (VirusScanner::InfectedFile)` is
raised. This means that an uploaded file exceeds [our size
limits][production-clamd-config] and cannot be scanned. To fix this, we'll
likely need to increase our limits, and running a scan locally can allow us to
experiment with the relevant setting. Various GOV.UK Helm Charts commits have
done this: [229e16e][], [5c33832][], and [a01862b][].

Other than Sentry error reporting, this is often surfaced via Zendesk support
tickets when a user tries to access an uploaded document and sees a JSON
response like this:

```json
{
  "_response_info": {
    "status": "not found"
  }
}
```

## Setup

You'll need to install the ClamAV CLI tool and set up its virus database before
you can run a scan. Below are example steps for setting this up using Homebrew
with an arm64 architecture macOS system (e.g. M1 or later).

1. Install the CLI tool: `brew install clamav`
1. Start the service: `brew services start clamav`
1. Create a config file for setting up the virus database:
   1. `cd /opt/homebrew/etc/clamav`
   1. `cp freshclam.conf.sample freshclam.conf`
   1. Edit the file created in the last step (`freshclam.conf`) and comment out
      the `Example` line with a `#`
   1. (Optional) Edit the config to more closely resemble the [config we use in
      production][production-freshclam-config]
1. Set up the virus database: `freshclam`

## Usage

Run the following command, adjusting arguments as appropriate (see the [clamscan
docs][clamscan-docs] or run `man clamscan` to learn more). You might want to
replicate relevant parts of our [production clamd
config][production-clamd-config] via these arguments for accurate testing.

```sh
clamscan --alert-exceeds-max=yes --max-files=35000 --max-scansize=2000M --max-filesize=500M filename.pdf
```

<!-- prettier-ignore-start -->
> [!TIP]
> For the example in
> [When might you run a local scan?](#when-might-you-run-a-local-scan), we
> adjusted the `--max-files` argument until the scan stopped reporting the
> `Heuristics.Limits.Exceeded.MaxFiles` error.
<!-- prettier-ignore-end -->

The scan might take a little while to complete. After it completes, it should
report the results. A report for a clean file should include lines like those
below (along with others).

```prose
filename.pdf OK

Scanned files: 1
Infected files: 0
```

[229e16e]:
  https://github.com/alphagov/govuk-helm-charts/commit/229e16e1ef5ad9d27a73aac42d3d9ec01f2c1d97
[5c33832]:
  https://github.com/alphagov/govuk-helm-charts/commit/5c3383247b3c15127c97b3ed95625f4604536b68
[a01862b]:
  https://github.com/alphagov/govuk-helm-charts/commit/a01862b99b626281d05ed425d8b0cf96a3456f02
[clamav]: https://www.clamav.net
[clamscan-docs]: https://docs.clamav.net/manual/Usage/Scanning.html#clamscan
[production-clamd-config]:
  https://github.com/alphagov/govuk-helm-charts/blob/a01862b99b626281d05ed425d8b0cf96a3456f02/charts/asset-manager/templates/clamav-configmap.yaml#L14-L35
[production-freshclam-config]:
  https://github.com/alphagov/govuk-helm-charts/blob/a01862b99b626281d05ed425d8b0cf96a3456f02/charts/asset-manager/templates/clamav-configmap.yaml#L36-L44
