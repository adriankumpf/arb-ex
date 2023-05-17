FROM elixir:1.14

ENV MIX_ENV=prod \
    RUST_VERSION="1.69.0" \
    PATH=/root/.cargo/bin:$PATH

RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- -y --profile minimal --default-toolchain $RUST_VERSION

RUN apt-get update && apt-get install -qqy --no-install-recommends \
    libusb-1.0-0-dev

RUN mix do local.hex --force, \
    local.rebar --force

WORKDIR /opt/app

COPY mix.exs mix.lock .
RUN mix do deps.get --only $MIX_ENV, deps.compile

COPY lib lib
COPY native native
RUN mix compile

CMD ["iex", "-S", "mix"]
