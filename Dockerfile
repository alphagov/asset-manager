ARG base_image=ghcr.io/alphagov/govuk-ruby-base:3.1.2
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:3.1.2

FROM $builder_image AS builder

WORKDIR /app
COPY Gemfile Gemfile.lock .ruby-version /app/
RUN bundle install
COPY . /app


FROM $base_image

ENV GOVUK_APP_NAME=asset-manager
ENV GOVUK_UPLOADS_ROOT=/tmp/uploads
# TODO: move ClamAV into a completely separate service.
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        clamav clamav-daemon clamdscan shared-mime-info && \
    rm -fr /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder /app /app/
RUN sed -Ei 's/\/var\/log\/clamav\/\w+\.log/\/dev\/stderr/; \
             s/LogRotate true/LogRotate false/; \
             s/LocalSocketGroup clamav/LocalSocketGroup app/; \
             s/LogFileUnlock false/LogFileUnlock true/; \
             s/TestDatabases yes/TestDatabases no/' \
        /etc/clamav/*clam*.conf
RUN mkdir -p /var/run/clamav && chown app:app /var/run/clamav /var/lib/clamav

USER app
CMD ["bundle", "exec", "puma"]
