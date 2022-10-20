ARG base_image=ghcr.io/alphagov/govuk-ruby-base:3.1.2
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:3.1.2

FROM $builder_image AS builder

WORKDIR /app

COPY Gemfile Gemfile.lock .ruby-version /app/

RUN apt update && \
    apt install shared-mime-info -y && \
    bundle install

COPY . /app

# TODO: investigate if this is needed.
RUN rm -rf /app/tmp


FROM $base_image

ENV GOVUK_APP_NAME=asset-manager GOVUK_ASSET_ROOT=http://assets-origin.dev.gov.uk

RUN apt update && \
    apt install -y --no-install-recommends clamav clamav-daemon shared-mime-info && \
    rm -fr /var/lib/apt/lists/*

WORKDIR /app

RUN ln -fs /tmp /app/tmp && \
    chown -R app:app /etc/clamav /var/lib/clamav

COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder /app /app/

USER app

CMD bundle exec puma
