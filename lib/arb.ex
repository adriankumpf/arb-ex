defmodule Arb do
  @moduledoc """
  A NIF for controlling the ABACOM CH341A relay board.
  """

  use Rustler,
    otp_app: :arb,
    crate: :arb_native

  @port_definition [
    type: :non_neg_integer,
    doc: "The USB port to be used. Only necessary if multiple relay boards are connected."
  ]

  @verify_definition [
    type: :boolean,
    doc: "Configures whether the activation should be verified.",
    default: true
  ]

  @typedoc """
  The relays are labeled from 1 to 8 according to the
  [data sheet](http://www.abacom-online.de/div/ABACOM_USB_LRB.pdf).
  """
  @type relay_id :: 1..8

  @doc """
  Activates the relays that correspond to the given a list of IDs. An empty
  list deactivates all relays.

  ## Options

  #{NimbleOptions.docs(port: @port_definition, verify: @verify_definition)}

  ## Examples

      iex> Arb.activate([1, 4, 7])
      :ok

  """
  @spec activate([relay_id], Keyword.t()) :: :ok | {:error, Arb.Error.t()}
  def activate(ids, opts \\ []) when is_list(ids) do
    Enum.each(ids, fn
      id when id in 1..8 -> :ok
      id -> raise ArgumentError, "expected a relay id between 1 and 8, got: #{inspect(id)}"
    end)

    opts = NimbleOptions.validate!(opts, port: @port_definition, verify: @verify_definition)
    __activate__(ids, opts[:verify], opts[:port]) |> to_ok()
  end

  @doc """
  Returns the ids of active relays.

  ## Options

  #{NimbleOptions.docs(port: @port_definition)}

  ## Examples

      iex> Arb.get_active()
      {:ok, [1, 3, 6]}

  """
  @spec get_active(Keyword.t()) :: {:ok, [relay_id]} | {:error, Arb.Error.t()}
  def get_active(opts \\ []) do
    opts = NimbleOptions.validate!(opts, port: @port_definition)
    __get_active__(opts[:port])
  end

  @doc """
  Resets the relay board.

  If, under some circumstances relay board operations fail due to a USB error
  e.g. `{:error, {:usb, "Input/Output Error"}}`, this function may resolve
  the issue by resetting the relay board. The effect is similar to replugging
  the device.

  **Note:** Previously activated relays stay active.

  ## Options

  #{NimbleOptions.docs(port: @port_definition)}

  ## Examples

      iex> Arb.reset()
      :ok

  """
  @spec reset(Keyword.t()) :: :ok | {:error, Arb.Error.t()}
  def reset(opts \\ []) do
    opts = NimbleOptions.validate!(opts, port: @port_definition)
    __reset__(opts[:port]) |> to_ok()
  end

  defp __activate__(_ids, _verify, _port), do: :erlang.nif_error(:nif_not_loaded)
  defp __get_active__(_port), do: :erlang.nif_error(:nif_not_loaded)
  defp __reset__(_port), do: :erlang.nif_error(:nif_not_loaded)

  defp to_ok({:ok, {}}), do: :ok
  defp to_ok(other), do: other
end
