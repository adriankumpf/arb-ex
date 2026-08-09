defmodule Arb do
  @moduledoc """
  A NIF for controlling the ABACOM CH341A relay board.

  ## Getting started

  Open a context once, name a board, and drive it:

      {:ok, usb} = Arb.open()
      board = Arb.board(usb)

      :ok = Arb.set_relays(board, [1, 4, 7])
      {:ok, [1, 4, 7]} = Arb.relays(board)
      :ok = Arb.set_relays(board, [])

  ## Holding the context

  `Arb.open/0` is expensive and every other call is not, so open a context when
  your application starts and hold it — see `Arb.Usb` for the figures and for how
  to replace one that has gone bad.

  One context for the node is enough: an `Arb.Usb` is safe to use from any
  process, and a board is claimed only for the duration of a single call. Holding
  one per process that drives a board buys no throughput — the saving is per
  *call* either way — but it does mean the process that hits a failure owns the
  context it has to rebuild, at the cost of an `Arb.open/0` in every `init/1`:

      defmodule MyApp.Board do
        use GenServer

        def init(port) do
          {:ok, usb} = Arb.open()
          {:ok, %{board: Arb.board(usb, port: port), usb: usb}}
        end
      end

  `Arb.Board` is the cheap half. It resolves nothing until an operation is called
  on it, so it can be built per call, held in state, or passed around freely.

  ## Checking the board

  `Arb.relays/1` is a plain read that takes the shift register at its word.
  `Arb.self_test/1` is the separate check that the board is still answering
  correctly; it moves no relay, so it is safe on a board driving live outputs.

  A read followed by a write is two claims rather than one — see `Arb.Board` for
  what that means on a board shared with another application.

  > #### Changed in 0.20.0 {: .warning}
  >
  > `get_active/1` used to run the self-test on the way past; `Arb.relays/1` does
  > not. Callers that relied on reading to vet the board must now call
  > `Arb.self_test/1` themselves.

  ## Telling boards apart

  These boards carry no identity of their own — no serial number, no
  manufacturer or product strings — so where a board is plugged in is the only
  thing distinguishing two of them. `inspect/1` renders that as
  `#Arb.Board<port 5 (1-5)>` for an enumerated board, in the notation `lsusb -t`
  uses.

  It follows that **if identical boards are unplugged and returned to different
  sockets, nothing in software can tell they were swapped** — a config naming
  port 5 will drive whatever is now on port 5, silently. Label the cables where
  that matters.
  """

  alias Arb.{Board, Native, Usb}

  @port_definition [
    type: {:in, 0..255},
    doc: """
    The USB port to select a specific board when multiple are connected. A port
    number is the board's port on the hub it is plugged into, so it is unique
    only among that hub's ports: two boards behind two hubs can both be on port
    3, and naming one then fails with `:multiple_found`. `list_boards/1` is the
    way out. Defaults to whichever board is attached.
    """
  ]

  @verify_definition [
    type: :boolean,
    doc: """
    Whether to read the shift register back after latching and fail with
    `{:verification_failed, expected, actual}` on a mismatch. The relays are
    latched *before* the read-back, so a failure leaves their physical state
    unknown — `relays/1` is how you find out what actually landed.
    """,
    default: true
  ]

  # Built once at compile time: `validate!/2` given a keyword list re-validates the
  # schema against NimbleOptions' own meta-schema on every call.
  @board_schema NimbleOptions.new!(port: @port_definition)
  @set_relays_schema NimbleOptions.new!(verify: @verify_definition)

  @typedoc """
  The relays are labeled from 1 to 8 according to the
  [data sheet](http://www.abacom-online.de/div/ABACOM_USB_LRB.pdf).
  """
  @type relay_id :: 1..8

  @typedoc "An option to `board/2`."
  @type board_option :: {:port, Board.port_no()}

  @typedoc "An option to `set_relays/3`."
  @type set_relays_option :: {:verify, boolean}

  @doc """
  Initialises libusb.

  Expensive relative to everything else, so open one context and hold it for the
  lifetime of your application — see `Arb.Usb`.

  ## Examples

      iex> {:ok, usb} = Arb.open()
      iex> is_struct(usb, Arb.Usb)
      true

  """
  @doc since: "0.20.0"
  @spec open() :: {:ok, Usb.t()} | {:error, Arb.Error.t()}
  def open, do: Native.open()

  @doc """
  Names a relay board reachable through `usb`.

  Resolves nothing and touches no hardware: the board is looked up when an
  operation is called on it, so nothing the hardware does can make this fail.

  It can still be called wrongly. A `:port` outside `0..255` raises
  `NimbleOptions.ValidationError` rather than returning an `Arb.Error` — that is
  a caller's mistake, not something a board reported, and the two are worth
  keeping apart. A port almost always arrives from configuration, though, so
  validate it where it enters your application if you would rather a
  misconfigured release fail there than raise out of an `init/1`.

  ## Options

  #{NimbleOptions.docs(@board_schema)}

  ## Examples

      iex> {:ok, usb} = Arb.open()
      iex> Arb.Board.port(Arb.board(usb))
      nil

      iex> {:ok, usb} = Arb.open()
      iex> Arb.Board.port(Arb.board(usb, port: 3))
      3

  """
  @doc since: "0.20.0"
  @spec board(Usb.t(), [board_option]) :: Board.t()
  def board(%Usb{reference: usb}, opts \\ []) do
    opts = NimbleOptions.validate!(opts, @board_schema)
    Native.board(usb, opts[:port])
  end

  @doc """
  Lists every attached relay board, in a stable order.

  Each board is named by where it sits on the USB tree rather than by port
  number, so an enumerated board always resolves back to the board it came from
  and never collides with another on the same port number.

  An empty list means no board is attached; that is not an error.

  ## Examples

      iex> {:ok, usb} = Arb.open()
      iex> {:ok, boards} = Arb.list_boards(usb)
      iex> is_list(boards)
      true

  """
  @doc since: "0.20.0"
  @spec list_boards(Usb.t()) :: {:ok, [Board.t()]} | {:error, Arb.Error.t()}
  def list_boards(%Usb{reference: usb}), do: Native.boards(usb)

  @doc """
  Activates the relays with the given ids, deactivating every relay not in the
  list. An empty list deactivates all relays.

  An id outside `1..8` raises `ArgumentError`, as a `:port` outside its range
  does on `board/2` and for the same reason. The ids are checked before the board
  is claimed, so one bad id cannot latch the good ones alongside it.

  ## Options

  #{NimbleOptions.docs(@set_relays_schema)}

  ## Examples

      Arb.set_relays(board, [1, 4, 7])
      #=> :ok

      Arb.set_relays(board, [], verify: false)
      #=> :ok

  """
  @doc since: "0.20.0"
  @spec set_relays(Board.t(), [relay_id], [set_relays_option]) ::
          :ok | {:error, Arb.Error.t()}
  def set_relays(%Board{reference: board}, ids, opts \\ []) when is_list(ids) do
    Enum.each(ids, fn
      id when id in 1..8 -> :ok
      id -> raise ArgumentError, "expected a relay id between 1 and 8, got: #{inspect(id)}"
    end)

    opts = NimbleOptions.validate!(opts, @set_relays_schema)
    to_ok(Native.set_relays(board, ids, opts[:verify]))
  end

  @doc """
  Returns the ids of the active relays, in ascending order.

  The ordering is guaranteed, so a comparison against a list you built the same
  way needs no `Enum.sort/1` on either side. An empty list means no relay is
  active.

  A plain read: it does not check that the board is answering correctly. That is
  `self_test/1`.

  ## Examples

      Arb.relays(board)
      #=> {:ok, [1, 3, 6]}

  """
  @doc since: "0.20.0"
  @spec relays(Board.t()) :: {:ok, [relay_id]} | {:error, Arb.Error.t()}
  def relays(%Board{reference: board}), do: Native.relays(board)

  @doc """
  Checks that the board answers correctly, without moving any relay.

  Writes an inverted test pattern through the shift register and reads it back.
  The pattern is never latched and the register's original contents are put back
  afterwards, so this is safe to call on a board driving live outputs. Fails with
  `:self_test_failed` if the pattern does not survive the round trip.

  A diagnostic rather than a guard on the operating path: `set_relays/3` with
  `verify: true` already writes, latches, reads back and compares within a single
  claim — everything this covers, on the value you actually asked for, plus the
  latch it never touches. And since a self-test is its own claim, it vouches for
  no particular `relays/1` call either side of it. Reach for it at startup, from a
  health check, or when a board is suspect.

  ## Examples

      Arb.self_test(board)
      #=> :ok

  """
  @doc since: "0.20.0"
  @spec self_test(Board.t()) :: :ok | {:error, Arb.Error.t()}
  def self_test(%Board{reference: board}), do: to_ok(Native.self_test(board))

  @doc """
  Performs a USB reset on the relay board.

  This resets the USB device, not the relays: **previously activated relays stay
  active**. If board operations start failing with a USB error — say
  `{:error, {:usb, "Input/Output Error"}}` — this may resolve it. The effect is
  similar to replugging the device.

  Including the part after the plug goes back in. The board re-enumerates, and
  until it is back every call answers `:not_found`. `:ok` here means the reset
  was issued, not that the board is ready — so **do not read the next call's
  failure as the reset having failed**.

  How long it stays away is the host's business: a hub, a loaded machine or
  another kernel each answer differently. `Arb.Error.retryable?/1` vouches for
  `:not_found`, so retrying until the board answers is what finds out; a delay
  guessed in advance is either too short or wasted.

  ## Examples

      Arb.reset_device(board)
      #=> :ok

  """
  @doc since: "0.20.0"
  @spec reset_device(Board.t()) :: :ok | {:error, Arb.Error.t()}
  def reset_device(%Board{reference: board}), do: to_ok(Native.reset_device(board))

  # Rustler encodes a unit `Ok` as `{:ok, {}}`; `:ok` is what Elixir expects.
  defp to_ok({:ok, {}}), do: :ok
  defp to_ok({:error, _reason} = error), do: error
end
