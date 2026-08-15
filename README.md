# arb-ex

[![Docs](https://img.shields.io/badge/hex-docs-green.svg?style=flat)](https://hexdocs.pm/arb)
[![Hex.pm](https://img.shields.io/hexpm/v/arb?color=%23714a94)](http://hex.pm/packages/arb)

An Elixir NIF for controlling the ABACOM CH341A relay board
([documentation](https://hexdocs.pm/arb)).

## Getting started

### Requirements

None. A precompiled NIF with [libusb](https://github.com/libusb/libusb) linked
into it is downloaded at build time, so neither the Rust toolchain nor
`libusb-1.0-0-dev` has to be installed. Artifacts are published for:

- **Linux** — `x86_64` and `aarch64` (glibc and musl), `armv7` (glibc)
- **macOS** — `aarch64`, `x86_64`

Anywhere else, Windows included, the NIF is compiled from source instead, which
needs Rust and a C compiler — still not `libusb`, which is built from the copy
vendored in the crate. `ARB_BUILD=true` forces a source build on a supported
target too.

### Installation

Add `:arb` to your list of dependencies:

```elixir
def deps do
  [
    {:arb, "~> 0.20"}
  ]
end
```

## Usage

Open a libusb context **once** and hold it — initialising one is by far the most
expensive part of talking to a board, and `Arb.Usb` has the figures. Naming a
board through it is free and resolves nothing until an operation runs.

```elixir
iex> {:ok, usb} = Arb.open()
iex> board = Arb.board(usb)

iex> Arb.set_relays(board, [1, 4, 7])
:ok

iex> Arb.relays(board)
{:ok, [1, 4, 7]}

iex> Arb.set_relays(board, [])
:ok
```

`Arb.relays/1` is a plain read. `Arb.self_test/1` is the separate health check —
it moves no relay, so it is safe on a board driving live outputs, and it hands
back the relays it found on its way past:

```elixir
iex> Arb.self_test(board)
{:ok, [1, 4, 7]}
```

With more than one board attached, `Arb.list_boards/1` enumerates them and names
each unambiguously:

```elixir
iex> {:ok, boards} = Arb.list_boards(usb)
iex> Enum.map(boards, &inspect/1)
["#Arb.Board<port 1 (1-1)>", "#Arb.Board<port 5 (1-5)>"]
```

These boards report no serial number and no product strings, so where a board is
plugged in is the only thing telling two of them apart — the `1-1` notation is
the one `lsusb -t` uses, so the two can be read side by side. Label the cables if
the relays drive anything that must not be actuated by mistake.

Migrating from 0.19 — where the three functions took a `:port` option and built a
context per call — is covered in the [changelog](CHANGELOG.md).

## Development

Rust is the only prerequisite. `config/config.exs` forces a source build in this
repo, so a clean clone works without setting anything:

```bash
mix test
```

Tests tagged `:libusb` exercise the real NIF and need a USB bus — not a relay
board. They run by default and are excluded only in CI, which has no bus at all
(see `.github/workflows/ci.yml`).

### Releasing

The precompiled artifacts have to exist before the package is published, because
the checksum file that pins them is built from what the release actually holds.

1. Bump `@version` in `mix.exs` and land it.
2. `git tag v<version> && git push origin master --tags` — this runs
   `.github/workflows/release.yml`, which builds every target and attaches the
   artifacts to the GitHub release.
3. Wait for all of them. A partial release yields a checksum file missing those
   targets, and users on them get a download error at compile time.
4. `mix rustler_precompiled.download Arb.Native --all --print`, which writes
   `checksum-Elixir.Arb.Native.exs`.
5. `mix hex.publish`. It refuses to build without that file.

## See also

- [abacom-relay-board](https://github.com/adriankumpf/abacom-relay-board)
