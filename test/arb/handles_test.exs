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
      # `board/2` may name no board at all; an enumerated one always carries the
      # port it was found on, plus the location that disambiguates it.
      assert Arb.port(board) != nil
      assert Arb.location(board) =~ ~r/^\d+-[\d.]+$/
      assert inspect(board) == "#Arb.Board<port #{Arb.port(board)} (#{Arb.location(board)})>"
    end
  end

  test "an enumerated board round-trips through its location" do
    # The whole point of the location: what `boards/1` found today must name the
    # same board after a restart, through nothing but a string in a config file.
    {:ok, usb} = Arb.open()
    {:ok, boards} = Arb.boards(usb)

    for board <- boards do
      assert {:ok, same} = Arb.board_at(usb, Arb.location(board))

      assert Arb.location(same) == Arb.location(board)
      assert Arb.port(same) == Arb.port(board)
      assert inspect(same) == inspect(board)
    end
  end

  test "a board named by port has no location to store" do
    {:ok, usb} = Arb.open()

    assert Arb.location(Arb.board(usb, port: 3)) == nil
    assert Arb.location(Arb.board(usb)) == nil
  end

  test "board_at rejects a malformed location at the point of naming" do
    {:ok, usb} = Arb.open()

    for bad <- ["", "1", "1-", "1-1.", "eth0", "1-256", "1-1.3 "] do
      assert {:error, %Arb.Error{reason: {:invalid_location, ^bad}}} = Arb.board_at(usb, bad)
    end
  end

  test "board_at accepts what a location renders as" do
    {:ok, usb} = Arb.open()

    for good <- ["1-3", "1-1.3", "2-1.2.3.4.5.6.7", "255-255"] do
      assert {:ok, board} = Arb.board_at(usb, good)
      assert Arb.location(board) == good
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
