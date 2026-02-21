defmodule ArbTest do
  use ExUnit.Case, async: true

  describe "activate/2" do
    for id <- [0, -1, 9, 256] do
      test "rejects relay ID #{id}" do
        assert_raise ArgumentError,
                     "expected a relay id between 1 and 8, got: #{unquote(id)}",
                     fn -> Arb.activate([unquote(id)]) end
      end
    end

    for {value, label} <- [{:foo, "atom"}, {"1", "string"}, {1.5, "float"}, {nil, "nil"}] do
      test "rejects non-integer relay ID (#{label})" do
        assert_raise ArgumentError, ~r/expected a relay id between 1 and 8/, fn ->
          Arb.activate([unquote(value)])
        end
      end
    end

    test "rejects non-list first argument" do
      assert_raise FunctionClauseError, fn -> Arb.activate(1) end
    end

    test "rejects invalid :port" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :port/, fn ->
        Arb.activate([], port: "foo")
      end
    end

    test "rejects invalid :verify" do
      assert_raise NimbleOptions.ValidationError, ~r/invalid value for :verify/, fn ->
        Arb.activate([], verify: "yes")
      end
    end

    test "rejects unknown options" do
      assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
        Arb.activate([], bogus: true)
      end
    end
  end

  for {fun, arity} <- [get_active: 1, reset: 1] do
    describe "#{fun}/#{arity}" do
      test "rejects invalid :port" do
        assert_raise NimbleOptions.ValidationError, ~r/invalid value for :port/, fn ->
          apply(Arb, unquote(fun), [[port: "foo"]])
        end
      end

      test "rejects unknown options" do
        assert_raise NimbleOptions.ValidationError, ~r/unknown options/, fn ->
          apply(Arb, unquote(fun), [[bogus: true]])
        end
      end
    end
  end
end
