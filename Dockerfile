ARG clamav_binary_src=https://www.clamav.net/downloads/production/clamav-1.3.1.tar.gz
ARG ruby_version=3.3
ARG base_image=ghcr.io/alphagov/govuk-ruby-base:$ruby_version
ARG builder_image=ghcr.io/alphagov/govuk-ruby-builder:$ruby_version

FROM --platform=$TARGETPLATFORM index.docker.io/library/ubuntu:22.04 AS clam_builder

ARG clamav_binary_src

WORKDIR /src

COPY . /src/

ENV DEBIAN_FRONTEND noninteractive
ENV CARGO_HOME /src/build

RUN apt update && apt install -y \
        cmake \
        bison \
        flex \
        gcc \
        git \
        make \
        man-db \
        net-tools \
        pkg-config \
        python3 \
        python3-pip \
        python3-pytest \
        check \
        libbz2-dev \
        libcurl4-openssl-dev \
        libjson-c-dev \
        libmilter-dev \
        libncurses-dev \
        libpcre2-dev \
        libssl-dev \
        libxml2-dev \
        zlib1g-dev \
        curl \
        wget \
    && \
    rm -rf /var/cache/apt/archives && \
    wget $clamav_binary_src && \
    tar -zxf clamav-1.3.1.tar.gz -C /src --strip-components=1 && ls && \
    # Using rustup to install Rust rather than rust:1.62.1-bullseye, because there is no rust:1.62.1-bullseye image for ppc64le at this time.
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && \
    . $CARGO_HOME/env \
    && \
    rustup update \
    && \
    mkdir -p "./build" && cd "./build" \
    && \
    cmake .. \
          -DCARGO_HOME=$CARGO_HOME \
          -DCMAKE_BUILD_TYPE="Release" \
          -DCMAKE_INSTALL_PREFIX="/usr" \
          -DCMAKE_INSTALL_LIBDIR="/usr/lib" \
          -DAPP_CONFIG_DIRECTORY="/etc/clamav" \
          -DDATABASE_DIRECTORY="/var/lib/clamav" \
          -DENABLE_CLAMONACC=OFF \
          -DENABLE_EXAMPLES=OFF \
          -DENABLE_JSON_SHARED=ON \
          -DENABLE_MAN_PAGES=OFF \
          -DENABLE_MILTER=ON \
          -DENABLE_STATIC_LIB=OFF \
    && \
    make DESTDIR="/clamav" -j$(($(nproc) - 1)) install \
    && \
    rm -r \
       "/clamav/usr/include" \
       "/clamav/usr/lib/pkgconfig/" \
    && \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /tmp/clamd.pid|" \
        -e "s|.*\(LocalSocket\) .*|\1 /tmp/clamd.sock|" \
        -e "s|.*\(TCPSocket\) .*|\1 3310|" \
        -e "s|.*\(TCPAddr\) .*|#\1 0.0.0.0|" \
        -e "s|.*\(User\) .*|\1 clamav|" \
        -e "s|^\#\(LogFile\) .*|\1 /var/log/clamav/clamd.log|" \
        -e "s|^\#\(LogTime\).*|\1 yes|" \
        "/clamav/etc/clamav/clamd.conf.sample" > "/clamav/etc/clamav/clamd.conf" && \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /tmp/freshclam.pid|" \
        -e "s|.*\(DatabaseOwner\) .*|\1 clamav|" \
        -e "s|^\#\(UpdateLogFile\) .*|\1 /var/log/clamav/freshclam.log|" \
        -e "s|^\#\(NotifyClamd\).*|\1 /etc/clamav/clamd.conf|" \
        -e "s|^\#\(ScriptedUpdates\).*|\1 yes|" \
        "/clamav/etc/clamav/freshclam.conf.sample" > "/clamav/etc/clamav/freshclam.conf" && \
    sed -e "s|^\(Example\)|\# \1|" \
        -e "s|.*\(PidFile\) .*|\1 /tmp/clamav-milter.pid|" \
        -e "s|.*\(MilterSocket\) .*|\1 inet:7357|" \
        -e "s|.*\(User\) .*|\1 clamav|" \
        -e "s|^\#\(LogFile\) .*|\1 /var/log/clamav/milter.log|" \
        -e "s|^\#\(LogTime\).*|\1 yes|" \
        -e "s|.*\(\ClamdSocket\) .*|\1 unix:/tmp/clamd.sock|" \
        "/clamav/etc/clamav/clamav-milter.conf.sample" > "/clamav/etc/clamav/clamav-milter.conf" || \
    exit 1 \
    && \
    ctest -V

FROM --platform=$TARGETPLATFORM $builder_image AS app_builder

WORKDIR $APP_HOME
COPY Gemfile Gemfile.lock .ruby-version ./
RUN bundle install
COPY . .
RUN bootsnap precompile --gemfile .

FROM --platform=$TARGETPLATFORM $base_image

ENV GOVUK_APP_NAME=asset-manager

# TODO: move ClamAV into a completely separate service.
RUN apt update && apt-get install -y libbz2-1.0 \
        wget \
        shared-mime-info \
        libcurl4 \
        libssl-dev \
        libjson-c5 \
        libmilter1.0.1 \
        libncurses6 \
        libpcre2-8-0 \
        libxml2 \
        zlib1g \
        tzdata \
        netcat && \
    mkdir -p /var/run/clamav /var/lib/clamav /usr/local/share/clamav && \
    chown app:app /var/run/clamav /var/lib/clamav /usr/local/share/clamav

WORKDIR $APP_HOME

COPY --from=clam_builder "/clamav" "/"
COPY --from=app_builder $BUNDLE_PATH $BUNDLE_PATH
COPY --from=app_builder $BOOTSNAP_CACHE_DIR $BOOTSNAP_CACHE_DIR
COPY --from=app_builder $APP_HOME .

USER app
CMD ["puma"]
