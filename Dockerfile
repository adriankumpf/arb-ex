FROM hexpm/elixir:1.20.3-erlang-29.0.5-debian-bookworm-20260803-slim AS releaser

ENV RUST_VERSION="1.97.1" \
    PATH=/root/.cargo/bin:$PATH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# No `libusb-1.0-0-dev`: the NIF vendors libusb and compiles it from source, so
# a C compiler is all that is needed.
RUN apt-get update && apt-get install -qqy --no-install-recommends \
    curl build-essential libsctp1

RUN curl https://sh.rustup.rs -sSf | \
    sh -s -- -y --profile minimal --default-toolchain $RUST_VERSION && \
    cargo --version

RUN mix do local.hex --force, \
    local.rebar --force

WORKDIR /opt/app

COPY mix.exs mix.lock ./
RUN mix do deps.get --only $MIX_ENV, deps.compile

COPY lib lib
COPY native native
COPY README.md LICENSE ./
RUN mix compile

CMD ["iex", "-S", "mix"]
