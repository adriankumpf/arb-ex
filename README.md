# arb-ex

[![Docs](https://img.shields.io/badge/hex-docs-green.svg?style=flat)](https://hexdocs.pm/arb)
[![Hex.pm](https://img.shields.io/hexpm/v/arb?color=%23714a94)](http://hex.pm/packages/arb)

An Elixir NIF for controlling the ABACOM CH341A relay board
([documentation](https://hexdocs.pm/arb)).

## Getting started

### Requirements

In order to compile a recent version of `rust` must be installed.
[libusb](https://github.com/libusb/libusb) is not required — it is built from
the copy vendored in the crate and linked into the NIF.

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
it moves no relay, so it is safe on a board driving live outputs.

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

```bash
docker build -t arb-ex .
docker run --privileged -it arb-ex
```

## See also

- [abacom-relay-board](https://github.com/adriankumpf/abacom-relay-board)
