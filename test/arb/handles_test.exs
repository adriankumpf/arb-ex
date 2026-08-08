defmodule Arb.HandlesTest do
  @moduledoc """
  Exercises the real NIF against libusb. Needs libusb — not a relay board:
  a context initialises and enumerates fine with nothing attached.

  Excluded with `mix test --exclude libusb` where libusb is unavailable.
  """

  use ExUnit.Case, async: true

  @moduletag :libusb

  doctest Arb

  test "a context opens and boards can be named through it" do
    assert {:ok, usb} = Arb.open()
    assert %Arb.Usb{} = usb

    assert %Arb.Board{} = board = Arb.board(usb)
    assert Arb.port(board) == nil

    assert %Arb.Board{} = board = Arb.board(usb, port: 3)
    assert Arb.port(board) == 3
  end

  test "enumeration answers with a list rather than :not_found when nothing is attached" do
    {:ok, usb} = Arb.open()

    assert {:ok, boards} = Arb.boards(usb)
    assert is_list(boards)
    assert Enum.all?(boards, &match?(%Arb.Board{}, &1))
  end

  test "an enumerated board is named unambiguously" do
    {:ok, usb} = Arb.open()
    {:ok, boards} = Arb.boards(usb)

    for board <- boards do
      # `usb.board(port)` may name no board at all; an enumerated one always
      # carries the port it was found on, plus the path that disambiguates it.
      assert Arb.port(board) != nil
      assert inspect(board) =~ ~r/^#Arb\.Board<port \d+ \(bus \d+, path [\d.]+\)>$/
    end
  end

  test "a context redacts its contents when inspected" do
    {:ok, usb} = Arb.open()
    assert inspect(usb) == "#Arb.Usb<>"
  end

  test "operations against no board report :not_found rather than crashing" do
    {:ok, usb} = Arb.open()

    # Names a port nothing is plugged into, so this is stable whether or not a
    # board happens to be attached to the machine running the suite.
    board = Arb.board(usb, port: 255)

    assert {:error, %Arb.Error{reason: :not_found}} = Arb.relays(board)
    assert {:error, %Arb.Error{reason: :not_found}} = Arb.self_test(board)
    assert {:error, %Arb.Error{reason: :not_found}} = Arb.reset_device(board)
    assert {:error, %Arb.Error{reason: :not_found}} = Arb.set_relays(board, [1])
  end
end
