ARG clam_version=1.5.4

FROM --platform=$TARGETPLATFORM ghcr.io/alphagov/govuk-ruby-builder:4.0 AS build
SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

ARG clam_version
ARG clam_url_prefix=https://github.com/Cisco-Talos/clamav/releases/download
ARG clam_url=$clam_url_prefix/clamav-${clam_version}/clamav-${clam_version}.tar.gz

WORKDIR /src
RUN curl -SLfso - "$clam_url" | tar -zxf - --strip-components=1

WORKDIR /src/build
# CVD_CERTS_DIRECTORY keeps the database signing certs out of /usr/local/etc,
# because the Helm chart mounts the clamd/freshclam config over that directory.
RUN install_packages \
      cmake pkg-config check libbz2-dev libcurl4-openssl-dev libjson-c-dev \
      libncurses-dev libpcre2-dev libxml2-dev zlib1g-dev cargo rustc \
      ; \
    cmake .. \
      -DCLAMAV_USER=app \
      -DCLAMAV_GROUP=app \
      -DCMAKE_BUILD_TYPE="Release" \
      -DCVD_CERTS_DIRECTORY="/usr/local/share/clamav/certs" \
      -DDATABASE_DIRECTORY="/var/lib/clamav" \
      -DENABLE_CLAMONACC=OFF \
      -DENABLE_JSON_SHARED=OFF \
      -DENABLE_MAN_PAGES=OFF \
      -DENABLE_MILTER=OFF \
      ; \
    make DESTDIR=/clamav -j$(nproc) install ; \
    rm -r /clamav/usr/local/{bin/clambc,include,lib/pkgconfig,share/doc}

FROM scratch
COPY --from=build /clamav /clamav
