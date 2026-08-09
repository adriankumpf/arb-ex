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

  `retryable?/1` and `moved_relays?/1` answer the two questions below as
  functions, so that a caller does not have to re-encode this list and go one
  release out of date. What follows is why they answer the way they do.

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

  @doc """
  Whether another attempt on the same handle is worth making.

  True for `:busy` and `:not_found`; see [Retrying](`t:reason/0`) for why, and
  for why a USB reset is the wrong answer to either. Everything else describes a
  board that answered wrongly, or a context that may have soured — see `Arb.Usb`
  for what to do with those. `{:unknown, _}` is among them: it carries a bug as
  readily as a variant from a newer `arb`, so it is not an "unclassified, treat
  gently" bucket. Nor is a reason this library grows later, until this function
  is taught otherwise.

  A function, not a guard, so a `when reason in [:busy, :not_found]` this
  replaces moves into the clause body.

  Takes a bare reason as well as the struct, for callers that cannot match
  `%Arb.Error{}` — a dependency declared `only: :prod`, say.

  ## Examples

      iex> Arb.Error.retryable?(%Arb.Error{reason: :busy, message: "in use"})
      true

      iex> Arb.Error.retryable?(:self_test_failed)
      false

  """
  @doc since: "0.20.0"
  @spec retryable?(t | reason) :: boolean
  def retryable?(%__MODULE__{reason: reason}), do: retryable?(reason)
  def retryable?(reason) when reason in [:busy, :not_found], do: true
  def retryable?(_reason), do: false

  @doc """
  Whether the failed operation may have left relays somewhere nobody knows.

  True only for `{:verification_failed, _, _}`, which latches before it reads
  back; every other reason either moved no relay or never reached the latch. It
  does not say where they landed — `Arb.relays/1` is how you find that out. See
  [Retrying](`t:reason/0`).

  Takes a bare reason as well as the struct, as `retryable?/1` does.

  ## Examples

      iex> Arb.Error.moved_relays?({:verification_failed, [1, 3], [1]})
      true

      iex> Arb.Error.moved_relays?(:self_test_failed)
      false

  """
  @doc since: "0.20.0"
  @spec moved_relays?(t | reason) :: boolean
  def moved_relays?(%__MODULE__{reason: reason}), do: moved_relays?(reason)
  def moved_relays?({:verification_failed, _expected, _actual}), do: true
  def moved_relays?(_reason), do: false
end
