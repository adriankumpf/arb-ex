defmodule Arb do
  @moduledoc """
  A NIF for controlling the ABACOM CH341A relay board.
  """

  alias Arb.{Native, Native.Options}

  @doc """
  Given a list of ids turns on the corresponding relays. An empty list turns off all relays.

  The relays are labeled from 1 to 8 according to the
  [data sheet](http://www.abacom-online.de/div/ABACOM_USB_LRB.pdf).

  ## Options

  The accepted options are:

    * `:verify` – configures whether the activation should be verfied (default: true)
    * `:port` – configures which USB port to use. Only necessary if multiple relay boards are
    connected (default: nil)

  ## Examples

      iex> Arb.activate([1, 4, 7])
      :ok

  """
  @spec activate(list(integer), Keyword.t()) :: :ok | {:error, atom}
  def activate(ids, opts \\ [])
  def activate(ids, opts) when is_list(ids), do: Native.activate(ids, struct(Options, opts))
  def activate(_ids, _opts), do: {:error, :invalid_args}

  @doc """
  Returns the ids of active relays.

  ## Examples

      iex> Arb.get_active()
      {:ok, [1, 3, 6]}

  """
  @spec get_active(integer) :: {:ok, list(integer)} | {:error, atom}
  def get_active(port \\ nil)
  def get_active(port) when is_integer(port) or is_nil(port), do: Native.get_active(port)
  def get_active(_port), do: {:error, :invalid_args}

  @doc """
  Resets the relay board.

  If, under some circumstances, relay board operations fail due to a USB error
  e.g. `{:error, {:usb, "Input/Output Error"}}`, this function may resolve
  the issue by reseting the relay board. The effect is similar to replugging
  the device.

  **Note:** Previously activated relays stay active.

  ## Examples

      iex> Arb.reset()
      :ok

  """
  @spec reset(integer) :: {:ok, list(integer)} | {:error, atom}
  def reset(port \\ nil)
  def reset(port) when is_integer(port) or is_nil(port), do: Native.reset(port)
  def reset(_port), do: {:error, :invalid_args}
end
