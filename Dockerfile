FROM hexpm/elixir:1.17.3-erlang-27.1.2-debian-bookworm-20241016 AS releaser

ENV RUST_VERSION="1.82.0" \
    PATH=/root/.cargo/bin:$PATH

RUN apt-get update && apt-get install -qqy --no-install-recommends \
    libusb-1.0-0-dev curl build-essential

RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- -y --profile minimal --default-toolchain $RUST_VERSION && \
    cargo --version

RUN mix do local.hex --force, \
    local.rebar --force

WORKDIR /opt/app

COPY mix.exs mix.lock .
RUN mix do deps.get --only $MIX_ENV, deps.compile

COPY lib lib
COPY native native
RUN mix compile

CMD ["iex", "-S", "mix"]
