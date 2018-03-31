defmodule Arb do
  @moduledoc """
  A NIF for controlling the ABACOM CH341A relay board.
  """

  alias Arb.{Native, Native.ActivateOptions}

  @doc """
  Given a list of ids turns on the corresponding relays. An empty list turns off all relays.

  ## Options

  The accepted options are:

    * `:verify` – configures whether the activation should be verfied (default: true)
    * `:port` – configures which USB port to use. Only necessary if multiple relay boards are
    connected (default: nil)

  ## Examples

      iex> Arb.activate([1, 4, 7], port: 2)
      :ok

  """
  @spec activate(list(integer), ActivateOptions.t()) :: :ok | {:error, atom}
  def activate(relays, opts \\ [])

  def activate(relays, opts) when is_list(relays) and is_list(opts),
    do: Native.activate(relays, struct(ActivateOptions, opts))

  def activate(_relays, _opts), do: {:error, :invalid_args}
end
