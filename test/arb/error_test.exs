defmodule Arb.ErrorTest do
  use ExUnit.Case, async: true

  # The wording itself belongs to `arb` and is pinned in `Arb.NativeTest`, where
  # a real error can catch a reword of the pinned revision. What is left here is
  # the contract: carried rendering wins, and a hand-built error still renders.

  test "message/1 returns the rendering the NIF carried" do
    error = %Arb.Error{reason: :not_found, message: "no relay board found"}
    assert Exception.message(error) == "no relay board found"
  end

  test "message/1 falls back to the reason when none was carried" do
    assert Exception.message(%Arb.Error{reason: :not_found}) == "arb error: :not_found"

    assert Exception.message(%Arb.Error{reason: {:verification_failed, [1, 3], [1]}}) ==
             "arb error: {:verification_failed, [1, 3], [1]}"
  end

  test "can be raised and rescued" do
    assert_raise Arb.Error, "no relay board found", fn ->
      raise Arb.Error, reason: :not_found, message: "no relay board found"
    end
  end
end
