defmodule Arb.Usb do
  @moduledoc """
  A libusb context: how relay boards are found.

  Built by `Arb.open/0`. Initialising it is by far the most expensive part of
  talking to a board — roughly 6.5 ms, against ~50 µs for everything else — so
  build one and hold it rather than opening one per call. `Arb` covers who
  should hold it, which the section below is the reason for.

  It claims nothing and opens nothing, so contexts never conflict with each
  other or with another application using the same board, and it is safe to use
  from any process.

  ## Not self-healing

  A held context does not recover on its own: if the USB controller resets or
  the host suspends, it can go permanently sour, where a per-call context would
  have been rebuilt anyway. Hold it in something swappable — a `GenServer`'s
  state, say — so it can be replaced.

  Don't try to detect that state. No error reliably distinguishes a dead context
  from a transient fault, so any classification would be guesswork. Since
  `Arb.open/0` is cheap next to the failures it recovers from, the robust policy
  is the simple one: **drop the struct and `Arb.open/0` a new one on any failure
  `Arb.Error.retry_in_place?/1` does not vouch for** — one it vouches for says
  nothing is wrong with the context, so retry in place first, and in particular
  do not answer it with `Arb.reset_device/1`.

  Rebuild the `Arb.Board` handles alongside the context: a board holds its own
  reference to the context it came from, so one kept across a reopen goes on
  using the old one.

  ## What a replacement can and cannot fix

  Both follow from `Arb.open/0` and `Arb.board/2` touching no hardware.

  A replacement is **unvetted**. It resolved nothing, so nothing about it says
  the board on the other end is answering; the first operation to use it is where
  you find out, and that is usually a write you would rather not have made on a
  bad board. `Arb.self_test/1` asks first, and moves no relay, so a board driving
  live outputs tolerates the question.

  A replacement **cannot reach the device**. Nothing about a fresh context
  changes what is on the wire, so a board that is wedged rather than
  mis-contexted fails through as many replacements as you care to make.
  `Arb.reset_device/1` is the remedy aimed at the device itself, which makes it
  the rung *after* replacing has stopped helping rather than a response to any
  particular error.

  Where "stopped helping" falls, and what happens when the reset does not help
  either, is yours — it depends on a supervision tree this library cannot see.
  But something has to escalate: a recovery that replaces the context forever
  never reaches the reset, and one that resets forever never reaches whatever you
  would do about a board that is simply broken.
  """
  @moduledoc since: "0.20.0"

  @enforce_keys [:reference]
  defstruct [:reference]

  @typedoc "A libusb context. Build it with `Arb.open/0`; the field is not public API."
  @type t :: %__MODULE__{reference: reference()}

  defimpl Inspect do
    def inspect(_usb, _opts), do: "#Arb.Usb<>"
  end
end
