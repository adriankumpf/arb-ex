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

  `retry_in_place?/1` and `relay_state_unknown?/1` answer the two questions below
  as functions, so that a caller does not have to re-encode this list and go one
  release out of date. What follows is why they answer the way they do.

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

  @doc """
  Whether the relays' physical position is unknown after the failure.

  True only for `{:verification_failed, _, _}`, which latches before it reads
  back; every other reason either moved no relay or never reached the latch.

  True is a statement of ignorance rather than of movement: the relays may sit at
  `expected`, at `actual`, or at neither, and `Arb.relays/1` is how you find out.
  False is the firm half — nothing latched. See [Retrying](`t:reason/0`).

  Takes a bare reason as well as the struct, as `retry_in_place?/1` does.

  ## Examples

      iex> Arb.Error.relay_state_unknown?({:verification_failed, [1, 3], [1]})
      true

      iex> Arb.Error.relay_state_unknown?(:self_test_failed)
      false

  """
  @doc since: "0.20.0"
  @spec relay_state_unknown?(t | reason) :: boolean
  def relay_state_unknown?(%__MODULE__{reason: reason}), do: relay_state_unknown?(reason)
  def relay_state_unknown?({:verification_failed, _expected, _actual}), do: true
  def relay_state_unknown?(_reason), do: false
end
