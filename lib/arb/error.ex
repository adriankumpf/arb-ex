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
  """
  @type reason ::
          :not_found
          | :multiple_found
          | :busy
          | :self_test_failed
          | {:verification_failed, expected :: [Arb.relay_id()], actual :: [Arb.relay_id()]}
          | {:invalid_relay, byte}
          | {:invalid_location, String.t()}
          | {:unexpected_transfer_length, String.t()}
          | {:usb, String.t()}
          | {:unknown, String.t()}

  @type t :: %__MODULE__{reason: reason}

  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: reason}) do
    case reason do
      :not_found ->
        "no relay board found"

      :multiple_found ->
        "multiple relay boards found"

      :busy ->
        "the relay board is in use by another application"

      :self_test_failed ->
        "self-test failed"

      {:verification_failed, expected, actual} ->
        "verification failed: expected #{render(expected)}, read back #{render(actual)}"

      {:invalid_relay, relay} ->
        "invalid relay: expected a number between 1 and 8, got #{relay}"

      {:invalid_location, location} ->
        "invalid board location: expected a bus and port path like `1-1.3`, got `#{location}`"

      {:unexpected_transfer_length, message} ->
        message

      {:usb, message} ->
        "libusb error: #{message}"

      {:unknown, message} ->
        message
    end
  end

  # Matches `arb`'s own rendering, where an empty set is `none` rather than an
  # empty string — "expected , read back 3" reads as a bug rather than as "no
  # relays".
  defp render([]), do: "none"
  defp render(ids), do: Enum.join(ids, " ")
end
