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

  `retry_in_place?/1` answers the question below as a function, so that a caller
  does not have to re-encode this list and go one release out of date. What
  follows is why it answers the way it does.

  `:busy` means another application held the board's USB interface for the
  duration of your call. It is normal on a shared board and says nothing is
  wrong, so **retry it, and do not `Arb.reset_device/1` in response** — a USB
  reset aimed at a board another application is mid-conversation with is the
  wrong answer to a routine collision. Retry loops written against 0.19, where
  this arrived as `{:usb, "Resource busy"}` and was indistinguishable from a real
  fault, will want that arm separated out.

  `:not_found` is also worth retrying — a board can be mid-re-enumeration.

  Neither is a promise that the wait is short. A peer using `arb` claims for one
  operation and is gone in microseconds, but anything else can hold the interface
  for as long as it likes, and a board unplugged for good never re-enumerates.
  Retrying stays the right answer in both cases — nothing else here helps — so a
  loop over them needs its own way out. See `Arb.Usb` for why that limit is yours
  to set.

  The remaining two describe a board that answered, and answered wrongly, so
  retrying does not fix them — but they differ in what they leave behind:

    * `:self_test_failed` moved no relay. The test pattern is written without
      latching, so only the read path is suspect.

    * `{:verification_failed, expected, actual}` latched the relays *before*
      reading back, so their physical state is unknown — `expected`, `actual`, or
      neither. `Arb.relays/1` is how you find out what actually landed.

  `{:register_out_of_sync, cause}` is the one where retrying is worse than
  useless. The relays hang off a shift register and reading it is destructive, so
  every read writes back what it consumed; this reason is that round trip coming
  apart. No relay moved, but the board's *account* of them is gone, and that
  account is what later reads report, so the next read can succeed and answer
  `{:ok, []}` for a board driving eight live outputs. `Arb.set_relays/3` writes
  the register and the outputs together, which is the way back. See [What a read
  reports](`Arb.relays/1`). `cause` is the transport failure that interrupted the
  round trip, carried for logging rather than for matching on.

  It is not the only failure that can leave the relays somewhere unknown, and
  which ones can is a property of the call rather than of the reason: the same
  `{:usb, _}` moved nothing on a read and may have latched on a write. See
  [After a failure](`Arb.set_relays/3`) for the rule, which is why there is no
  function here to ask — this type does not carry what the answer depends on.
  """
  @type reason ::
          :not_found
          | :multiple_found
          | :busy
          | :self_test_failed
          | {:verification_failed, expected :: [Arb.relay_id()], actual :: [Arb.relay_id()]}
          | {:unexpected_transfer_length, String.t()}
          | {:register_out_of_sync, cause :: String.t()}
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

  @doc """
  Whether to retry the same call on the same handle, changing nothing else.

  True for `:busy` and `:not_found`; see [Retrying](`t:reason/0`) for why, and
  for why a USB reset is the wrong answer to either. *In place* is the whole of
  the claim — retry, rather than replace the context or reset the device — and it
  holds however long the condition lasts, which is not this library's to predict.

  Everything else describes a board that answered wrongly, or a context that may
  have soured — see `Arb.Usb` for what to do with those. `{:unknown, _}` is among
  them: it carries a bug as readily as a variant from a newer `arb`, so it is not
  an "unclassified, treat gently" bucket. Nor is a reason this library grows
  later, until this function is taught otherwise.

  `{:register_out_of_sync, _}` is the sharpest case of `false` meaning something
  rather than nothing: a retried read there succeeds and hands back a confident
  wrong answer. Write a known state instead.

  A function, not a guard, so a `when reason in [:busy, :not_found]` this
  replaces moves into the clause body.

  Takes a bare reason as well as the struct, for callers that cannot match
  `%Arb.Error{}` — a dependency declared `only: :prod`, say.

  ## Examples

      iex> Arb.Error.retry_in_place?(%Arb.Error{reason: :busy, message: "in use"})
      true

      iex> Arb.Error.retry_in_place?(:self_test_failed)
      false

  """
  @doc since: "0.20.0"
  @spec retry_in_place?(t | reason) :: boolean
  def retry_in_place?(%__MODULE__{reason: reason}), do: retry_in_place?(reason)
  def retry_in_place?(reason) when reason in [:busy, :not_found], do: true
  def retry_in_place?(_reason), do: false
end
