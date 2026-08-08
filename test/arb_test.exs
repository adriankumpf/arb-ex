defmodule ArbTest do
  use ExUnit.Case, async: true

  # A `Arb.Board` names a board; it resolves nothing until an operation runs
  # against the hardware. Every check below happens before that point, so a
  # fabricated handle is enough and the suite stays hardware-free. If validation
  # ever moved behind the NIF, these would start failing with a decode error
  # instead of quietly passing.
  defp board do
    %Arb.Board{reference: make_ref(), port: 3, description: "port 3"}
  end

  describe "set_relays/3" do
    for id <- [0, -1, 9, 256] do
      test "rejects relay ID #{id}" do
        assert_raise ArgumentError,
                     "expected a relay id between 1 and 8, got: #{unquote(id)}",
                     fn -> Arb.set_relays(board(), [unquote(id)]) end
      end
    end

    for {value, label} <- [{:foo, "atom"}, {"1", "string"}, {1.5, "float"}, {nil, "nil"}] do
      test "rejects non-integer relay ID (#{label})" do
        assert_raise ArgumentError, ~r/expected a relay id between 1 and 8/, fn ->
          Arb.set_relays(board(), [unquote(value)])
        end
      end
    end

    test "rejects a non-list relay argument" do
      # Use Function.identity/1 to hide the type from compile-time analysis
      assert_raise FunctionClauseError, fn -> Arb.set_relays(board(), Function.identity(1)) end
    end

    test "rejects something that is not a board" do
      assert_raise FunctionClauseError, fn -> Arb.set_relays(Function.identity(:board), []) end
    end

    test "rejects invalid :verify" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :verify/, fn ->
        Arb.set_relays(board(), [], verify: "yes")
      end
    end

    test "rejects unknown options" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Arb.set_relays(board(), [], bogus: true)
      end
    end
  end

  describe "board/2" do
    test "rejects a port outside a byte" do
      # `arb` takes a `u8`; without this the value would reach the NIF and fail
      # to decode with an opaque ArgumentError.
      for port <- [-1, 256, 1000] do
        assert_raise NimbleOptions.ValidationError, ~r/invalid value for :port/, fn ->
          Arb.board(%Arb.Usb{reference: make_ref()}, port: port)
        end
      end
    end

    test "rejects a non-integer port" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :port/, fn ->
        Arb.board(%Arb.Usb{reference: make_ref()}, port: "foo")
      end
    end

    test "rejects unknown options" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Arb.board(%Arb.Usb{reference: make_ref()}, bogus: true)
      end
    end

    test "rejects something that is not a context" do
      assert_raise FunctionClauseError, fn -> Arb.board(Function.identity(:usb)) end
    end
  end

  describe "port/1" do
    test "returns the port a board is named by" do
      assert Arb.port(board()) == 3
    end

    test "returns nil for a board that names no particular board" do
      assert Arb.port(%Arb.Board{reference: make_ref(), description: "any board"}) == nil
    end
  end

  for {fun, arg} <- [relays: :board, self_test: :board, reset_device: :board, boards: :usb] do
    describe "#{fun}/1" do
      test "rejects something that is not a #{arg}" do
        assert_raise FunctionClauseError, fn ->
          apply(Arb, unquote(fun), [Function.identity(unquote(arg))])
        end
      end
    end
  end
end
