# arb-ex

An Elixir NIF for controlling the ABACOM CH341A relay board ([documentation](https://hexdocs.pm/arb)).

## Getting started

### Requirements

In order to compile a recent version of `rust` must be installed (tested with 1.25). Also, the native [libusb](https://github.com/libusb/libusb) library is required. On Debian-based distributions install `libusb-1.0-0-dev`.

### Installation

**Note:** this package is still in beta and thus not yet available on Hex.

Add `:arb` to your list of dependencies:

```elixir
def deps do
  [
    {:arb, "~> 0.2.0"}
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

* [abacom-relay-board](https://github.com/adriankumpf/abacom-relay-board)
