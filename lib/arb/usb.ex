defmodule Arb.Usb do
  @moduledoc """
  A libusb context: how relay boards are found.

  Built by `Arb.open/0`. Initialising it is by far the most expensive part of
  talking to a board — roughly 6.5 ms, against ~50 µs for everything else — so
  build one and hold it for the lifetime of the node.

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
  that is not already known to be retryable** — `:busy` and `:not_found` say
  nothing is wrong with the context, so retry those in place first. See
  `Arb.Error`.

  Rebuild the `Arb.Board` handles alongside the context: a board holds its own
  reference to the context it came from, so one kept across a reopen goes on
  using the old one.
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
