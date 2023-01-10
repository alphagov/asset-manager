ARG ruby_version=3.1.2
ARG base_image=ghcr.io/alphagov/govuk-ruby-base:$ruby_version
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:$ruby_version


FROM $builder_image AS builder

WORKDIR $APP_HOME
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install
COPY . .
RUN bootsnap precompile --gemfile .


FROM $base_image

ENV GOVUK_APP_NAME=asset-manager

# TODO: move ClamAV into a completely separate service.
RUN install_packages clamav clamav-daemon clamdscan shared-mime-info && \
    rm -fr /etc/clamav/* && \
    mkdir -p /var/run/clamav && \
    chown app:app /var/run/clamav /var/lib/clamav

WORKDIR $APP_HOME
COPY --from=builder $BUNDLE_PATH $BUNDLE_PATH
COPY --from=builder $BOOTSNAP_CACHE_DIR $BOOTSNAP_CACHE_DIR
COPY --from=builder $APP_HOME .

USER app
CMD ["puma"]
