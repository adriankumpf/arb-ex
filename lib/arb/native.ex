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

  def activate(_ids, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def get_active(_port), do: :erlang.nif_error(:nif_not_loaded)
  def reset(_port), do: :erlang.nif_error(:nif_not_loaded)
end
