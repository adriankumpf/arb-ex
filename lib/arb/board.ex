defmodule Arb.Board do
  @moduledoc """
  One relay board, found and claimed afresh for the duration of every call.

  Built by `Arb.board/2`, `Arb.board_at/2` or `Arb.boards/1`. A board holds a
  selector — not a device and not a USB claim — so it is free to build, resolves
  nothing until an operation is called on it, and may outlive or predate the
  device it names. Several boards, in this node or in another application, can
  drive the same hardware.

  ## Naming a board

  `Arb.port/1` is a label: a port number is the board's port on the hub it is
  plugged into, so it is unique only among that hub's ports and two boards behind
  two hubs can share it.

  `Arb.location/1` is the identifier. It is `nil` for a board named by port, and
  a string like `"1-1.3"` for one from `Arb.boards/1` or `Arb.board_at/2` — the
  spelling `lsusb -t` uses, and the one `Arb.board_at/2` parses back. That round
  trip is what lets a configuration file name a specific board across restarts.

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
  defstruct [:reference, :port, :location]

  @typedoc """
  A relay board handle. Opaque apart from `Arb.port/1` and `Arb.location/1`;
  build it with `Arb.board/2`, `Arb.board_at/2` or `Arb.boards/1`.
  """
  @opaque t :: %__MODULE__{
            reference: reference(),
            port: Arb.port_no() | nil,
            location: Arb.location() | nil
          }

  defimpl Inspect do
    # Mirrors `arb`'s own rendering of a board, which is what `arb --list`
    # prints: `port 3 (1-1.3)`, `port 3`, or `any board`.
    def inspect(%Arb.Board{port: nil}, _opts), do: "#Arb.Board<any board>"

    def inspect(%Arb.Board{port: port, location: nil}, _opts) do
      "#Arb.Board<port #{port}>"
    end

    def inspect(%Arb.Board{port: port, location: location}, _opts) do
      "#Arb.Board<port #{port} (#{location})>"
    end
  end
end
