FROM hexpm/elixir:1.18.4-erlang-28.0.1-debian-bookworm-20250630-slim AS releaser

ENV RUST_VERSION="1.88.0" \
    PATH=/root/.cargo/bin:$PATH

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -qqy --no-install-recommends \
    libusb-1.0-0-dev curl build-essential

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
