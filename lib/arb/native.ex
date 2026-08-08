defmodule Arb.Native do
  @moduledoc false

  # The NIF stubs, kept off `Arb` so that the module users read the docs of is
  # plain Elixir and exposes nothing it does not mean to. `Inspect.Arb.Board`
  # reaches `describe/1` through here rather than through a public `Arb` function
  # that exists only for it.

  use Rustler,
    otp_app: :arb,
    crate: :arb_native

  def open, do: :erlang.nif_error(:nif_not_loaded)
  def board(_usb, _port), do: :erlang.nif_error(:nif_not_loaded)
  def boards(_usb), do: :erlang.nif_error(:nif_not_loaded)
  def describe(_board), do: :erlang.nif_error(:nif_not_loaded)
  def set_relays(_board, _ids, _verify), do: :erlang.nif_error(:nif_not_loaded)
  def relays(_board), do: :erlang.nif_error(:nif_not_loaded)
  def self_test(_board), do: :erlang.nif_error(:nif_not_loaded)
  def reset_device(_board), do: :erlang.nif_error(:nif_not_loaded)
end
