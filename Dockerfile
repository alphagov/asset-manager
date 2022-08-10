ARG base_image=ghcr.io/alphagov/govuk-ruby-base:2.7.6
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:2.7.6
 
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
    apt install -y clamav shared-mime-info

WORKDIR /app

RUN ln -fs /tmp /app/tmp

RUN ln -sf /usr/bin/clamscan /usr/bin/govuk_clamscan && \
    freshclam && \
    sed -i '/UpdateLogFile/d' /etc/clamav/freshclam.conf

COPY --from=builder /usr/local/bundle/ /usr/local/bundle/
COPY --from=builder /app /app/

USER app

CMD bundle exec puma
