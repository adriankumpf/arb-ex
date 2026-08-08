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
  have been rebuilt anyway. Callers that must survive that should drop the
  struct and `Arb.open/0` a new one after repeated failures — which is why
  holding it in something swappable (a `GenServer`'s state, say) is worth the
  trouble.
  """
  @moduledoc since: "0.20.0"

  @enforce_keys [:reference]
  defstruct [:reference]

  @typedoc "A libusb context. Opaque: build it with `Arb.open/0`."
  @opaque t :: %__MODULE__{reference: reference()}

  defimpl Inspect do
    def inspect(_usb, _opts), do: "#Arb.Usb<>"
  end
end
