# arb-ex

An Elixir NIF for controlling the ABACOM CH341A relay board
([documentation](https://hexdocs.pm/arb)).

## Getting started

### Requirements

In order to compile a recent version of `rust` (stable; 2018 edition) must be
installed. Also, the native [libusb](https://github.com/libusb/libusb) library
is required (e.g `libusb-1.0-0-dev` on Debian-based distributions).

### Installation

Add `:arb` to your list of dependencies:

```elixir
def deps do
  [
    {:arb, "~> 0.6"}
  ]
end
```

## Usage

```elixir
iex> Arb.activate([1, 4, 7])
:ok

iex> Arb.get_active()
{:ok, [1, 4, 7]}
```

## Development

```bash
docker build -t arb-ex .
docker run --privileged -it arb-ex
```

## See also

- [abacom-relay-board](https://github.com/adriankumpf/abacom-relay-board)
