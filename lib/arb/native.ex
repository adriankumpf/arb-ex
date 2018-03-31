defmodule Arb.Native.ActivateOptions do
  @type t :: [port: nil | integer, verify: boolean]

  defstruct port: nil,
            verify: true
end

defmodule Arb.Native do
  use Rustler, otp_app: :arb, crate: "arb"

  def activate(_relays, _opts), do: error()

  defp error, do: :erlang.nif_error(:nif_not_loaded)
end
