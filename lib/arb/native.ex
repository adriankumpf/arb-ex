defmodule Arb.Native.Options do
  @type t :: [port: nil | integer, verify: boolean]

  defstruct port: nil, verify: true
end

defmodule Arb.Native do
  use Rustler, otp_app: :arb, crate: "arb"

  def activate(_ids, _opts), do: error()

  def get_active(_port), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
