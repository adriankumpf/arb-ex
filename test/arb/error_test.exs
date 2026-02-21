defmodule Arb.ErrorTest do
  use ExUnit.Case, async: true

  @reasons_and_messages [
    {:not_found, "no relay board found"},
    {:multiple_found, "multiple relay boards found"},
    {:verification_failed, "verification failed"},
    {:bad_device, "Usb device malfunction"},
    {{:io, "broken pipe"}, "I/O operation failed: broken pipe"},
    {{:usb, "Input/Output Error"}, "libusb error: Input/Output Error"}
  ]

  for {reason, expected} <- @reasons_and_messages do
    test "message/1 with #{inspect(reason)}" do
      error = %Arb.Error{reason: unquote(Macro.escape(reason))}
      assert Exception.message(error) == unquote(expected)
    end
  end

  test "can be raised and rescued" do
    assert_raise Arb.Error, "no relay board found", fn ->
      raise Arb.Error, reason: :not_found
    end
  end
end
