defmodule Arb.Board do
  @moduledoc """
  One relay board, found and claimed afresh for the duration of every call.

  Built by `Arb.board/2` or `Arb.list_boards/1`. A board holds a selector — not a
  device and not a USB claim — so it is free to build, resolves nothing until an
  operation is called on it, and may outlive or predate the device it names.
  Several boards, in this node or in another application, can drive the same
  hardware.

  ## Atomicity

  One operation is atomic — a single claim spans all of it, read-back included —
  but a *sequence* of them is not. `Arb.relays/1` followed by
  `Arb.set_relays/3` is two claims, so on a board shared with another
  application a write can land in the gap and be silently lost:

      # Racy on a shared board: a write between these two calls is overwritten.
      {:ok, active} = Arb.relays(board)
      :ok = Arb.set_relays(board, [3 | active])

  The board latches all eight relays at once, so there is no partial update to
  reach for instead. Where the hardware is shared and read-modify-write is
  unavoidable, serialise it outside this library.
  """
  @moduledoc since: "0.20.0"

  @enforce_keys [:reference]
  defstruct [:reference, :port]

  @typedoc """
  A relay board handle. Build it with `Arb.board/2` or `Arb.list_boards/1`, and
  read it with `port/1` or `inspect/1` — the fields are not public API.
  """
  @type t :: %__MODULE__{reference: reference(), port: port_no() | nil}

  @typedoc "A USB port number."
  @type port_no :: 0..255

  @doc """
  Returns the USB port `board` is named by, or `nil` if it names no particular
  board.

  A label, not an identifier — see the `:port` option on `Arb.board/2`. Use
  `inspect/1` to tell two boards apart.
  """
  @doc since: "0.20.0"
  @spec port(t()) :: port_no() | nil
  def port(%__MODULE__{port: port}), do: port

  defimpl Inspect do
    def inspect(%{reference: board}, _opts) do
      "#Arb.Board<" <> Arb.Native.describe(board) <> ">"
    end
  end
end
