defmodule Arb.Error do
  @moduledoc """
  An exception for errors returned by the `arb` library.
  """
  @moduledoc since: "0.9.0"

  @typedoc """
  Why an operation failed.

  New reasons may be added in a minor release — the underlying Rust error type
  is non-exhaustive, and anything it grows arrives here as `{:unknown, message}`
  rather than crashing the NIF — so `case` and `with` over this type want a
  catch-all clause.

  ## Retrying

  `:busy` means another application held the board's USB interface for the
  duration of your call. It is normal on a shared board and says nothing is
  wrong, so **retry it, and do not `Arb.reset_device/1` in response** — a USB
  reset aimed at a board another application is mid-conversation with is the
  wrong answer to a routine collision. Retry loops written against 0.19, where
  this arrived as `{:usb, "Resource busy"}` and was indistinguishable from a real
  fault, will want that arm separated out.

  `:not_found` is also worth retrying — a board can be mid-re-enumeration.

  The remaining two describe a board that answered, and answered wrongly, so
  retrying does not fix them — but they differ in what they leave behind:

    * `:self_test_failed` moved no relay. The test pattern is written without
      latching, so only the read path is suspect.

    * `{:verification_failed, expected, actual}` latched the relays *before*
      reading back, so their physical state is unknown — `expected`, `actual`, or
      neither. `Arb.relays/1` is how you find out what actually landed.
  """
  @type reason ::
          :not_found
          | :multiple_found
          | :busy
          | :self_test_failed
          | {:verification_failed, expected :: [Arb.relay_id()], actual :: [Arb.relay_id()]}
          | {:unexpected_transfer_length, String.t()}
          | {:usb, String.t()}
          | {:unknown, String.t()}

  @typedoc """
  An `arb` error.

  `reason` is the part to match on; `message` is the rendering, and comes from
  `arb` itself rather than being re-derived here — there is no second copy of
  those strings to drift when the pinned revision moves.
  """
  @type t :: %__MODULE__{reason: reason, message: String.t() | nil}

  defexception [:reason, :message]

  @impl true
  def message(%__MODULE__{message: message}) when is_binary(message), do: message

  # Only reached for a struct built by hand — anything from the NIF carries its
  # own rendering.
  def message(%__MODULE__{reason: reason}), do: "arb error: #{inspect(reason)}"
end
