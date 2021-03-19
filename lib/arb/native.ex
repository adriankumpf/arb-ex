defmodule Arb.Native.Options do
  @moduledoc false

  @type t :: [port: nil | integer, verify: boolean]

  defstruct port: nil, verify: true
end

defmodule Arb.Native do
  @moduledoc false

  use Rustler,
    otp_app: :arb,
    crate: :arb

  def activate(ids, opts), do: __activate__(ids, opts) |> to_ok()
  def get_active(port), do: __get_active__(port)
  def reset(port), do: __reset__(port) |> to_ok()

  defp __activate__(_ids, _opts), do: :erlang.nif_error(:nif_not_loaded)
  defp __get_active__(_port), do: :erlang.nif_error(:nif_not_loaded)
  defp __reset__(_port), do: :erlang.nif_error(:nif_not_loaded)

  defp to_ok({:ok, {}}), do: :ok
  defp to_ok(other), do: other
end
