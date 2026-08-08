# arb-ex

[![Docs](https://img.shields.io/badge/hex-docs-green.svg?style=flat)](https://hexdocs.pm/arb)
[![Hex.pm](https://img.shields.io/hexpm/v/arb?color=%23714a94)](http://hex.pm/packages/arb)

An Elixir NIF for controlling the ABACOM CH341A relay board
([documentation](https://hexdocs.pm/arb)).

## Getting started

### Requirements

In order to compile a recent version of `rust` must be installed. Also, the
native [libusb](https://github.com/libusb/libusb) library is required (e.g
`libusb-1.0-0-dev` on Debian-based distributions).

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

Open a libusb context **once** and hold it — that is by far the most expensive
part of talking to a board (~6.5 ms, against ~50 µs for everything else). Naming
a board through it is free and resolves nothing until an operation runs.

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
it moves no relay, so it is safe on a board driving live outputs.

With more than one board attached, `Arb.boards/1` enumerates them and names each
unambiguously:

```elixir
iex> {:ok, boards} = Arb.boards(usb)
iex> Enum.map(boards, &Arb.location/1)
["1-1.3", "1-1.4"]
```

A location is the `lsusb -t` spelling of where a board sits on the USB tree, and
unlike a port number it never collides — so it is what belongs in configuration
when a host has more than one board:

```elixir
iex> {:ok, board} = Arb.board_at(usb, System.fetch_env!("RELAY_BOARD"))
```

Migrating from 0.19 — where the three functions took a `:port` option and built a
context per call — is covered in the [changelog](CHANGELOG.md).

## Development

```bash
docker build -t arb-ex .
docker run --privileged -it arb-ex
```

## See also

- [abacom-relay-board](https://github.com/adriankumpf/abacom-relay-board)
