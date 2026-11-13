ARG ruby_version=4.0
ARG base_image=ghcr.io/alphagov/govuk-ruby-base:$ruby_version
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:$ruby_version

FROM --platform=$TARGETPLATFORM $builder_image AS app_builder

WORKDIR $APP_HOME
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install
COPY . .
RUN bootsnap precompile --gemfile .


FROM --platform=$TARGETPLATFORM $base_image
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ENV GOVUK_APP_NAME=asset-manager

# ClamAV now comes from the org's shared image (ghcr.io/alphagov/govuk/clamav)
# Here we only need the clamdscan client and freshclam for signature updates
RUN install_packages libcurl4t64 shared-mime-info netcat-openbsd \
      clamdscan clamav-freshclam ; \
    mkdir -p /var/lib/clamav ; \
    chown app:app /var/lib/clamav
# Crude smoke test and print library versions.
RUN echo -n clamdscan:\ ; clamdscan --version -c /dev/null ; \
    ldd $(which clamdscan) ; \
    echo -n freshclam:\ ; freshclam --version --config-file /dev/null ; \
    ldd $(which freshclam)

WORKDIR $APP_HOME
COPY --from=app_builder $BUNDLE_PATH $BUNDLE_PATH
COPY --from=app_builder $BOOTSNAP_CACHE_DIR $BOOTSNAP_CACHE_DIR
COPY --from=app_builder $APP_HOME .

USER app
CMD ["puma"]
