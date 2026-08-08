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

  `Arb.open/0` initialises libusb, which costs roughly 6.5 ms; every other call
  costs about 50 µs. Opening one per operation — which is what versions before
  0.20.0 did internally — therefore spends over a hundred times the work of the
  operation itself. Open one `Arb.Usb` when your application starts and hold it.

  Ownership is yours rather than this library's, because the right place to keep
  it differs per application and because a held context is **not self-healing**:
  see `Arb.Usb` for when to drop one and open another.

  `Arb.Board` is the cheap half — it resolves nothing until an operation is
  called on it, so it can be built per call, held alongside the context, or
  passed around freely.

  ## Checking the board

  `Arb.relays/1` is a plain read that takes the shift register at its word.
  `Arb.self_test/1` is the separate health check: it writes a test pattern
  through the register and back without ever latching it, so it moves no relay
  and is safe on a board driving live outputs. It costs about as much again as a
  read, so call it when a board is suspect or periodically — not on every read.

  > #### Changed in 0.20.0 {: .warning}
  >
  > `get_active/1` used to run that check on the way past. `Arb.relays/1` does
  > not. Callers that relied on reading to vet the board must call
  > `Arb.self_test/1` themselves.
  """

  use Rustler,
    otp_app: :arb,
    crate: :arb_native

  alias Arb.{Board, Usb}

  @port_definition [
    type: {:in, 0..255},
    doc: """
    The USB port to select a specific board when multiple are connected. A port
    number is the board's port on the hub it is plugged into, so it is unique
    only among that hub's ports: two boards behind two hubs can both be on port
    3, and naming one then fails with `:multiple_found`. `boards/1` is the way
    out. Defaults to whichever board is attached.
    """
  ]

  @verify_definition [
    type: :boolean,
    doc: """
    Whether to read the shift register back after latching and fail with
    `:verification_failed` on a mismatch.
    """,
    default: true
  ]

  @typedoc """
  The relays are labeled from 1 to 8 according to the
  [data sheet](http://www.abacom-online.de/div/ABACOM_USB_LRB.pdf).
  """
  @type relay_id :: 1..8

  @typedoc "A USB port number."
  @type port_no :: 0..255

  @typedoc """
  Where a board sits on the USB tree, in the spelling `lsusb -t` uses: the bus,
  then the hub ports leading down to it — `"1-1.3"` is port 3 of the hub on port
  1 of bus 1.

  Unlike a port number this never collides, so it is the thing to put in a
  configuration file when a host has more than one board.
  """
  @type location :: String.t()

  @doc """
  Initialises libusb.

  Expensive (~6.5 ms) relative to everything else, so open one context and hold
  it for the lifetime of your application — see `Arb.Usb`.

  ## Examples

      iex> {:ok, usb} = Arb.open()
      iex> is_struct(usb, Arb.Usb)
      true

  """
  @doc since: "0.20.0"
  @spec open() :: {:ok, Usb.t()} | {:error, Arb.Error.t()}
  def open, do: __open__()

  @doc """
  Names a relay board reachable through `usb`.

  Resolves nothing and touches no hardware: the board is looked up when an
  operation is called on it, so this cannot fail.

  ## Options

  #{NimbleOptions.docs(port: @port_definition)}

  ## Examples

      iex> {:ok, usb} = Arb.open()
      iex> Arb.board(usb) |> Arb.port()
      nil

      iex> {:ok, usb} = Arb.open()
      iex> Arb.board(usb, port: 3) |> Arb.port()
      3

  """
  @doc since: "0.20.0"
  @spec board(Usb.t(), keyword) :: Board.t()
  def board(%Usb{} = usb, opts \\ []) do
    opts = NimbleOptions.validate!(opts, port: @port_definition)
    __board__(usb, opts[:port])
  end

  @doc """
  Returns every attached relay board, in a stable order.

  Each board is named by where it sits on the USB tree rather than by port
  number, so an enumerated board always resolves back to the board it came from
  and never collides with another on the same port number.

  An empty list means no board is attached; that is not an error.

  ## Examples

      iex> {:ok, usb} = Arb.open()
      iex> {:ok, boards} = Arb.boards(usb)
      iex> is_list(boards)
      true

  """
  @doc since: "0.20.0"
  @spec boards(Usb.t()) :: {:ok, [Board.t()]} | {:error, Arb.Error.t()}
  def boards(%Usb{} = usb), do: __boards__(usb)

  @doc """
  Names the board at `location`, wherever it is plugged in.

  The way back from `location/1`: a board found by `boards/1` can be written
  down and named again later, which naming it by port cannot do, since a port
  number is only unique among one hub's ports.

  Touches no hardware. The only thing that can fail is parsing `location`, which
  is the point — a mistyped configuration value fails at startup rather than
  resolving to nothing at the first relay switch.

  ## Examples

      iex> {:ok, usb} = Arb.open()
      iex> {:ok, board} = Arb.board_at(usb, "1-1.3")
      iex> Arb.location(board)
      "1-1.3"

      iex> {:ok, usb} = Arb.open()
      iex> Arb.board_at(usb, "not-a-location")
      {:error, %Arb.Error{reason: {:invalid_location, "not-a-location"}}}

  """
  @doc since: "0.20.0"
  @spec board_at(Usb.t(), location()) :: {:ok, Board.t()} | {:error, Arb.Error.t()}
  def board_at(%Usb{} = usb, location) when is_binary(location) do
    __board_at__(usb, location)
  end

  @doc """
  Returns where `board` sits on the USB tree, or `nil` if it names no particular
  board.

  A string like `"1-1.3"`, and the identifier `port/1` is not: store it, and
  `board_at/2` resolves it back to the same board across restarts. `nil` for a
  board from `board/2`, which names a port rather than a board and so has
  nothing stable to report.
  """
  @doc since: "0.20.0"
  @spec location(Board.t()) :: location() | nil
  def location(%Board{location: location}), do: location

  @doc """
  Returns the USB port `board` is named by, or `nil` if it names no particular
  board.

  A label, not an identifier — see the `:port` option on `board/2`.
  `location/1` is the identifier, and `inspect/1` renders both.
  """
  @doc since: "0.20.0"
  @spec port(Board.t()) :: port_no() | nil
  def port(%Board{port: port}), do: port

  @doc """
  Activates the relays with the given ids, deactivating every relay not in the
  list. An empty list deactivates all relays.

  ## Options

  #{NimbleOptions.docs(verify: @verify_definition)}

  ## Examples

      Arb.set_relays(board, [1, 4, 7])
      #=> :ok

      Arb.set_relays(board, [], verify: false)
      #=> :ok

  """
  @doc since: "0.20.0"
  @spec set_relays(Board.t(), [relay_id], keyword) :: :ok | {:error, Arb.Error.t()}
  def set_relays(%Board{} = board, ids, opts \\ []) when is_list(ids) do
    Enum.each(ids, fn
      id when id in 1..8 -> :ok
      id -> raise ArgumentError, "expected a relay id between 1 and 8, got: #{inspect(id)}"
    end)

    opts = NimbleOptions.validate!(opts, verify: @verify_definition)
    __set_relays__(board, ids, opts[:verify]) |> to_ok()
  end

  @doc """
  Returns the ids of the active relays.

  A plain read: it does not check that the board is answering correctly. That is
  `self_test/1`.

  ## Examples

      Arb.relays(board)
      #=> {:ok, [1, 3, 6]}

  """
  @doc since: "0.20.0"
  @spec relays(Board.t()) :: {:ok, [relay_id]} | {:error, Arb.Error.t()}
  def relays(%Board{} = board), do: __relays__(board)

  @doc """
  Checks that the board answers correctly, without moving any relay.

  Writes an inverted test pattern through the shift register and reads it back.
  The pattern is never latched and the register's original contents are put back
  afterwards, so this is safe to call on a board driving live outputs. Fails with
  `:self_test_failed` if the pattern does not survive the round trip.

  ## Examples

      Arb.self_test(board)
      #=> :ok

  """
  @doc since: "0.20.0"
  @spec self_test(Board.t()) :: :ok | {:error, Arb.Error.t()}
  def self_test(%Board{} = board), do: __self_test__(board) |> to_ok()

  @doc """
  Performs a USB reset on the relay board.

  This resets the USB device, not the relays: **previously activated relays stay
  active**. If board operations start failing with a USB error — say
  `{:error, {:usb, "Input/Output Error"}}` — this may resolve it. The effect is
  similar to replugging the device.

  ## Examples

      Arb.reset_device(board)
      #=> :ok

  """
  @doc since: "0.20.0"
  @spec reset_device(Board.t()) :: :ok | {:error, Arb.Error.t()}
  def reset_device(%Board{} = board), do: __reset_device__(board) |> to_ok()

  defp __open__, do: :erlang.nif_error(:nif_not_loaded)
  defp __board__(_usb, _port), do: :erlang.nif_error(:nif_not_loaded)
  defp __board_at__(_usb, _location), do: :erlang.nif_error(:nif_not_loaded)
  defp __boards__(_usb), do: :erlang.nif_error(:nif_not_loaded)
  defp __set_relays__(_board, _ids, _verify), do: :erlang.nif_error(:nif_not_loaded)
  defp __relays__(_board), do: :erlang.nif_error(:nif_not_loaded)
  defp __self_test__(_board), do: :erlang.nif_error(:nif_not_loaded)
  defp __reset_device__(_board), do: :erlang.nif_error(:nif_not_loaded)

  defp to_ok({:ok, {}}), do: :ok
  defp to_ok(other), do: other
end
