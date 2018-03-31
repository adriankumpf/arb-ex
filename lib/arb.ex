defmodule Arb do
  @moduledoc """
  A NIF for controlling the ABACOM CH341A relay board.
  """

  alias Arb.{Native, Native.Options}

  @doc """
  Given a list of ids turns on the corresponding relays. An empty list turns off all relays.

  ## Options

  The accepted options are:

    * `:verify` – configures whether the activation should be verfied (default: true)
    * `:port` – configures which USB port to use. Only necessary if multiple relay boards are
    connected (default: nil)

  ## Examples

      iex> Arb.activate([1, 4, 7])
      :ok

  """
  @spec activate(list(integer), Options.t()) :: :ok | {:error, atom}
  def activate(ids, opts \\ [])
  def activate(ids, opts) when is_list(ids), do: Native.activate(ids, struct(Options, opts))
  def activate(_ids, _opts), do: {:error, :invalid_args}

  @doc """
  Returns a list of ids whose relays are active.

  ## Examples

      iex> Arb.get_active()
      {:ok, [1, 3, 6]}

  """
  @spec get_active(integer) :: {:ok, list(integer)} | {:error, atom}
  def get_active(port \\ nil)
  def get_active(port) when is_integer(port) or is_nil(port), do: Native.get_active(port)
  def get_active(_port), do: {:error, :invalid_args}
end
