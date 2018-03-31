# Arb

A NIF for controlling the ABACOM CH341A relay board ([documentation](https://hexdocs.pm/fritz_api)).

## Installation

Add `:arb` to your list of dependencies:

```elixir
def deps do
  [
    {:arb, "~> 0.1.0"}
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
