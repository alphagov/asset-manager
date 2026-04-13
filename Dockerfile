ARG clam_version=1.3.1
ARG ruby_version=3.4
ARG base_image=ghcr.io/alphagov/govuk-ruby-base:$ruby_version
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:$ruby_version


FROM --platform=$TARGETPLATFORM $builder_image AS clam_builder
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG clam_version
ARG clam_url_prefix=https://github.com/Cisco-Talos/clamav/releases/download
ARG clam_url=$clam_url_prefix/clamav-${clam_version}/clamav-${clam_version}.tar.gz

WORKDIR /src
RUN curl -SLfso - "$clam_url" | tar -zxf - --strip-components=1

WORKDIR /src/build
RUN install_packages \
      cmake pkg-config check libbz2-dev libcurl4-openssl-dev libjson-c-dev \
      libncurses-dev libpcre2-dev libxml2-dev zlib1g-dev cargo rustc \
      ; \
    cmake .. \
      -DCLAMAV_USER=app \
      -DCLAMAV_GROUP=app \
      -DCMAKE_BUILD_TYPE="Release" \
      -DDATABASE_DIRECTORY="/var/lib/clamav" \
      -DENABLE_CLAMONACC=OFF \
      -DENABLE_JSON_SHARED=OFF \
      -DENABLE_MAN_PAGES=OFF \
      -DENABLE_MILTER=OFF \
      ; \
    make DESTDIR=/clamav -j$(nproc) install ; \
    rm -r /clamav/usr/local/{bin/clambc,include,lib/pkgconfig,share/doc}


FROM --platform=$TARGETPLATFORM $builder_image AS app_builder

WORKDIR $APP_HOME
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install
COPY . .
RUN bootsnap precompile --gemfile .


FROM --platform=$TARGETPLATFORM $base_image
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ENV GOVUK_APP_NAME=asset-manager

# TODO: move ClamAV into a completely separate service or (better) stop trying
# to run our own antimalware and use a hosted service (such as VirusTotal or
# S3 Malware Scanning or similar).
RUN install_packages shared-mime-info netcat-openbsd ; \
    mkdir -p /var/lib/clamav ; \
    chown app:app /var/lib/clamav
COPY --from=clam_builder /clamav /
# Crude smoke test and print library versions.
RUN echo -n clamd:\ ; clamd --version -c /dev/null ; \
    ldd $(which clamd) ; \
    echo -n clamdscan:\ ; clamdscan --version -c /dev/null ; \
    ldd $(which clamdscan)

WORKDIR $APP_HOME
COPY --from=app_builder $BUNDLE_PATH $BUNDLE_PATH
COPY --from=app_builder $BOOTSNAP_CACHE_DIR $BOOTSNAP_CACHE_DIR
COPY --from=app_builder $APP_HOME .

USER app
CMD ["puma"]
