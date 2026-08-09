defmodule Arb.NativeTest do
  @moduledoc """
  Exercises the real NIF against libusb. Needs libusb — not a relay board:
  a context initialises and enumerates fine with nothing attached.

  Excluded with `mix test --exclude libusb` where libusb is unavailable.
  """

  use ExUnit.Case, async: true

  @moduletag :libusb

  doctest Arb

  setup do
    {:ok, usb} = Arb.open()
    %{usb: usb}
  end

  test "a context opens and boards can be named through it", %{usb: usb} do
    assert %Arb.Usb{} = usb

    assert %Arb.Board{} = board = Arb.board(usb)
    assert Arb.Board.port(board) == nil

    assert %Arb.Board{} = board = Arb.board(usb, port: 3)
    assert Arb.Board.port(board) == 3
  end

  test "enumeration answers with a list rather than :not_found when nothing is attached",
       %{usb: usb} do
    assert {:ok, boards} = Arb.list_boards(usb)
    assert is_list(boards)
    assert Enum.all?(boards, &match?(%Arb.Board{}, &1))
  end

  test "a named board renders the way the docs say it does", %{usb: usb} do
    # `arb` owns this rendering, so pin it: a bump of the pinned revision would
    # otherwise change public `inspect/1` output with nothing here to notice.
    assert inspect(Arb.board(usb)) == "#Arb.Board<any board>"
    assert inspect(Arb.board(usb, port: 5)) == "#Arb.Board<port 5>"
  end

  test "an enumerated board is named unambiguously", %{usb: usb} do
    {:ok, boards} = Arb.list_boards(usb)

    for board <- boards do
      # `Arb.board/2` may name no board at all; an enumerated one always carries
      # the port it was found on, plus the `lsusb -t` path that disambiguates it.
      assert Arb.Board.port(board) != nil
      assert inspect(board) =~ ~r/^#Arb\.Board<port \d+ \(\d+-[\d.]+\)>$/
    end
  end

  test "a context redacts its contents when inspected", %{usb: usb} do
    assert inspect(usb) == "#Arb.Usb<>"
  end

  test "operations against no board report :not_found rather than crashing", %{usb: usb} do
    # Names a port nothing is plugged into, so this is stable whether or not a
    # board happens to be attached to the machine running the suite.
    board = Arb.board(usb, port: 255)

    assert {:error, %Arb.Error{reason: :not_found}} = Arb.relays(board)
    assert {:error, %Arb.Error{reason: :not_found}} = Arb.self_test(board)
    assert {:error, %Arb.Error{reason: :not_found}} = Arb.reset_device(board)
    assert {:error, %Arb.Error{reason: :not_found}} = Arb.set_relays(board, [1])
  end

  test "an error carries `arb`'s own rendering", %{usb: usb} do
    {:error, error} = Arb.relays(Arb.board(usb, port: 255))

    # `arb` owns this wording and `Arb.Error` no longer keeps a copy, so pin it
    # here: a bump of the pinned revision that rewords it would otherwise change
    # what users are shown with nothing to notice.
    assert Exception.message(error) == "no relay board found"
  end
end
