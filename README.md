# Asset Manager (Mule)

This is an application to manage uploaded assets (images, PDFs etc.)
for various applications.

Initially, this will only be an API, and the asset serving mechanism,
but it may well develop an admin interface in time.

## Prerequisites

Virus scanning expects `govuk_clamscan` to exist on the PATH,
and be a symlink to either `clamscan` or `clamdscan`, which are
part of `clamav`.
