defmodule Arb.Error do
  @moduledoc """
  An exception for errors returned by the `arb` library.
  """
  @moduledoc since: "0.9.0"

  @type reason ::
          :not_found
          | :multiple_found
          | :verification_failed
          | :unsafe_read
          | :bad_device
          | {:io, String.t()}
          | {:usb, String.t()}

  @type t :: %__MODULE__{reason: reason}

  defexception [:reason]

  @impl true
  def message(%__MODULE__{reason: reason}) do
    case reason do
      :not_found -> "no relay board found"
      :multiple_found -> "multiple relay boards found"
      :verification_failed -> "verification failed"
      :unsafe_read -> "Reading would exceeded the expected buffer size"
      :bad_device -> "Usb device malfunction"
      {:io, message} -> "I/O operation failed: #{message}"
      {:usb, message} -> "libusb error: #{message}"
    end
  end
end
