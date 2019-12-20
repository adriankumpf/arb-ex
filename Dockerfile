FROM elixir:1.9

ENV RUST_VERSION="1.40.0" \
    MIX_ENV="prod"

WORKDIR /opt/app

RUN apt-get update && apt-get install -qqy --no-install-recommends \
       libusb-1.0-0-dev \
    && rm -rf /var/lib/apt/lists/*

RUN RUST_ARCHIVE="rust-$RUST_VERSION-x86_64-unknown-linux-gnu.tar.gz" && \
    RUST_DOWNLOAD_URL="https://static.rust-lang.org/dist/$RUST_ARCHIVE" && \
    mkdir -p /rust \
    && cd /rust \
    && curl -fsOSL $RUST_DOWNLOAD_URL \
    && curl -s $RUST_DOWNLOAD_URL.sha256 | sha256sum -c - \
    && tar -C /rust -xzf $RUST_ARCHIVE --strip-components=1 \
    && rm $RUST_ARCHIVE \
    && ./install.sh

COPY lib lib
COPY native native
COPY mix.exs .
COPY mix.lock .

RUN mix do \
    local.hex --force, local.rebar --force, \
    deps.get, deps.compile, compile.rustler

CMD ["iex", "-S", "mix"]
