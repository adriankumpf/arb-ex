defmodule Arb.ErrorTest do
  use ExUnit.Case, async: true

  @reasons_and_messages [
    {:not_found, "no relay board found"},
    {:multiple_found, "multiple relay boards found"},
    {:busy, "the relay board is in use by another application"},
    {:self_test_failed, "self-test failed"},
    {{:verification_failed, [1, 3], [1]}, "verification failed: expected 1 3, read back 1"},
    {{:verification_failed, [1], []}, "verification failed: expected 1, read back none"},
    {{:verification_failed, [], [4]}, "verification failed: expected none, read back 4"},
    {{:invalid_relay, 9}, "invalid relay: expected a number between 1 and 8, got 9"},
    {{:invalid_location, "1-"},
     "invalid board location: expected a bus and port path like `1-1.3`, got `1-`"},
    {{:unexpected_transfer_length, "unexpected usb transfer length: expected 8 bytes, got 0"},
     "unexpected usb transfer length: expected 8 bytes, got 0"},
    {{:usb, "Input/Output Error"}, "libusb error: Input/Output Error"},
    {{:unknown, "some new upstream variant"}, "some new upstream variant"}
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
