ARG ruby_version=3.2.2
ARG base_image=ghcr.io/alphagov/govuk-ruby-base:$ruby_version
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:$ruby_version
ARG clam_engine=clamav-1.2.1.linux.x86_64.deb

FROM $builder_image AS builder

WORKDIR $APP_HOME
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install
COPY . .
RUN bootsnap precompile --gemfile .


FROM $base_image

ARG clam_engine
ENV GOVUK_APP_NAME=asset-manager

# TODO: move ClamAV into a completely separate service.
RUN install_packages wget shared-mime-info && \
    wget https://www.clamav.net/downloads/production/$clam_engine && \
    apt install ./$clam_engine && rm ./$clam_engine && \
    mkdir -p /var/run/clamav /var/lib/clamav /usr/local/share/clamav && \
    chown app:app /var/run/clamav /var/lib/clamav /usr/local/share/clamav

WORKDIR $APP_HOME
COPY --from=builder $BUNDLE_PATH $BUNDLE_PATH
COPY --from=builder $BOOTSNAP_CACHE_DIR $BOOTSNAP_CACHE_DIR
COPY --from=builder $APP_HOME .

USER app
CMD ["puma"]
