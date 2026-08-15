defmodule Arb.ErrorTest do
  use ExUnit.Case, async: true

  # Unlike `doctest Arb`, these need no libusb: classification is pure.
  doctest Arb.Error

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

  # Every reason in `t:Arb.Error.reason/0` falls in one of the two lists below,
  # and "classifies every reason in the type" reads the type back to prove it —
  # so a reason added without a decision here fails a test rather than falling
  # into a catch-all unnoticed.
  @retry_in_place [:busy, :not_found]

  @verification_failed {:verification_failed, [1, 3], [1]}

  @fatal [
    :multiple_found,
    :self_test_failed,
    @verification_failed,
    {:unexpected_transfer_length, "read 3 of 4 bytes"},
    # Not merely unhelped by a retry: a retried read succeeds and lies.
    {:register_out_of_sync, "Operation timed out"},
    {:usb, "Input/Output Error"},
    {:unknown, "something new"}
  ]

  describe "retry_in_place?/1" do
    test "retries a collision and a board that is still enumerating" do
      for reason <- @retry_in_place do
        assert Arb.Error.retry_in_place?(reason)
        assert Arb.Error.retry_in_place?(%Arb.Error{reason: reason})
      end
    end

    test "does not retry a board that answered wrongly or a context that may have soured" do
      for reason <- @fatal do
        refute Arb.Error.retry_in_place?(reason)
        refute Arb.Error.retry_in_place?(%Arb.Error{reason: reason})
      end
    end
  end

  test "classifies every reason in the type" do
    assert MapSet.new(reason_tags()) ==
             MapSet.new(@retry_in_place ++ @fatal, &tag/1)
  end

  # The leading atom is what distinguishes one reason from another; the payload
  # types are `arb`'s business and are pinned in `Arb.NativeTest`.
  defp tag(reason) when is_atom(reason), do: reason
  defp tag(reason) when is_tuple(reason), do: elem(reason, 0)

  defp reason_tags do
    {:ok, types} = Code.Typespec.fetch_types(Arb.Error)

    {_kind, {:reason, {:type, _, :union, members}, []}} =
      Enum.find(types, fn {_kind, {name, _ast, _args}} -> name == :reason end)

    Enum.map(members, fn
      {:atom, _, tag} -> tag
      {:type, _, :tuple, [{:atom, _, tag} | _]} -> tag
    end)
  end
end
