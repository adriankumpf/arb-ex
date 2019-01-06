FROM erlang:20.3

ENV ELIXIR_VERSION="v1.7.4" \
    RUST_VERSION="1.31.0" \
    LANG="C.UTF-8" \
    MIX_ENV="prod" \
    HOME=/opt/app

WORKDIR $HOME

RUN apt-get update && \
    apt-get install \
       ca-certificates \
       curl \
       gcc \
       libc6-dev \
       libusb-1.0-0-dev \
       psmisc \
       -qqy \
       --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Install Elixir
RUN set -xe \
    && ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/${ELIXIR_VERSION}.tar.gz" \
    && curl -fSL -o elixir-src.tar.gz $ELIXIR_DOWNLOAD_URL \
    && mkdir -p /usr/local/src/elixir \
    && tar -xzC /usr/local/src/elixir --strip-components=1 -f elixir-src.tar.gz \
    && rm elixir-src.tar.gz \
    && cd /usr/local/src/elixir \
    && make install clean

# Install Hex
RUN mix do local.hex --force, local.rebar --force

# Install Rust
RUN RUST_ARCHIVE="rust-$RUST_VERSION-x86_64-unknown-linux-gnu.tar.gz" && \
    RUST_DOWNLOAD_URL="https://static.rust-lang.org/dist/$RUST_ARCHIVE" && \
    mkdir -p /rust \
    && cd /rust \
    && curl -fsOSL $RUST_DOWNLOAD_URL \
    && curl -s $RUST_DOWNLOAD_URL.sha256 | sha256sum -c - \
    && tar -C /rust -xzf $RUST_ARCHIVE --strip-components=1 \
    && rm $RUST_ARCHIVE \
    && ./install.sh

COPY . .

RUN mix do deps.get, deps.compile, compile.rustler

CMD ["iex", "-S", "mix"]
