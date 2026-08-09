# Changelog

## [0.20.0-rc.0] — unreleased

Tracks `arb` 0.8.0, which replaced its three free functions with a libusb
context and a board handle. This release passes that shape through to Elixir:
**every 0.19 entry point is gone.**

### Migrating from 0.19

Open a context once and hold it. `Arb.open/0` costs ~6.5 ms; every other call
costs ~50 µs. Before 0.20 each call paid the 6.5 ms.

```elixir
# Once, when your application starts
{:ok, usb} = Arb.open()

# Free to build, resolves nothing until an operation runs
board = Arb.board(usb, port: 3)

:ok = Arb.set_relays(board, [1, 3])
{:ok, active} = Arb.relays(board)
:ok = Arb.reset_device(board)
```

| 0.19                                | 0.20                                                            |
| ----------------------------------- | --------------------------------------------------------------- |
| `Arb.activate(ids, port: p)`        | `Arb.set_relays(Arb.board(usb, port: p), ids)`                   |
| `Arb.activate(ids, verify: false)`  | `Arb.set_relays(board, ids, verify: false)`                      |
| `Arb.get_active(port: p)`           | `Arb.relays(board)` — **no longer self-tests**                   |
| `Arb.reset(port: p)`                | `Arb.reset_device(board)`                                        |
| —                                   | `Arb.open/0`, `Arb.board/2`, `Arb.list_boards/1`                 |
| —                                   | `Arb.self_test/1`, the check `get_active/1` used to run silently |
| `:bad_device`                       | `:self_test_failed`                                              |
| `:verification_failed`              | `{:verification_failed, expected, actual}`                       |
| `{:io, msg}`                        | gone — no library path could produce it                          |
| —                                   | `:busy`, `{:unknown, msg}`                                       |

Three behaviour changes the table does not show:

- **`relays/1` does not self-test.** `get_active/1` silently wrote an inverted
  pattern to the shift register, read it back and undid it. If you read in order
  to vet the board, call `self_test/1` yourself
- **A held context is not self-healing.** 0.19 built a fresh one per call and so
  recovered from a soured libusb state by accident; 0.20 does not. Hold it
  somewhere swappable, per process or per board — `Arb` and `Arb.Usb` cover when
  to replace one and what a replacement does not fix
- **`reset_device/1` returns before the board is back.** `:ok` means the reset
  was issued; the board re-enumerates, so a `:not_found` right after is not the
  reset having failed

### Changed (**breaking**)

- Replace `activate/2`, `get_active/1` and `reset/1` with `set_relays/3`,
  `relays/1` and `reset_device/1`, taking an `Arb.Board` rather than a `:port`
  option. `reset/1` read like "turn all the relays off"; it is a USB reset and
  leaves the relay outputs untouched
- Split the board's self-test out of the read, halving its cost — 28 USB
  transfers rather than 56. The check is now `self_test/1`
- Give `:verification_failed` the relay ids it expected and read back; it
  previously carried nothing
- Rename `:bad_device` to `:self_test_failed`
- Report a board held by another application as `:busy` rather than
  `{:usb, "Resource busy"}`, which made it indistinguishable from a real USB
  fault even though it is routine and worth retrying as it stands
- Validate `:port` as a byte. `arb` takes a `u8`, so a larger number previously
  reached the NIF and failed to decode with an opaque `ArgumentError`
- Carry `arb`'s own rendering on `Arb.Error` as `:message` instead of re-deriving
  it in Elixir. Errors the NIF produces read as before; a hand-built
  `%Arb.Error{}` carrying no `:message` now renders as its reason

### Removed (**breaking**)

- The `{:io, message}` error reason, which no library path could produce

### Added

- `Arb.open/0` and `Arb.Usb`, the libusb context
- `Arb.board/2` and `Arb.Board`, a handle to one board. It holds a selector, not
  a device and not a USB claim, so it is free to build and never locks another
  application out of a shared board
- `Arb.list_boards/1`, which returns every attached board in a stable order,
  named by where it sits on the USB tree rather than by port number. An empty
  list means no board is attached rather than `:not_found`
- `Arb.Board.port/1`, and an `Inspect` for `Arb.Board` that renders
  `#Arb.Board<port 3 (1-1.3)>` — enough to tell apart two boards sharing a port
  number
- `Arb.self_test/1`, the read-back check `get_active/1` used to perform on the
  way past. It moves no relay, so it is safe to call on a live board
- `Arb.Error.retry_in_place?/1` and `Arb.Error.relay_state_unknown?/1` — which
  reasons are worth another attempt as they stand, and which one leaves the
  relays somewhere unknown — so a caller no longer re-encodes that list and goes
  a release out of date. Each takes a bare reason as well as an `%Arb.Error{}`,
  for callers that cannot match the struct
- The `{:unknown, message}` error reason, which is how a variant added to `arb`'s
  non-exhaustive error type reaches Elixir
- `t:Arb.board_option/0` and `t:Arb.set_relays_option/0`, so the accepted option
  values are visible in the specs

### Fixed

Inherited from `arb` 0.8.0:

- Re-attach the kernel driver when the USB interface is released. It was
  previously detached on open and never restored
- Raise the USB bulk timeouts to 1000 ms, from 10 ms for reads and 100 ms for
  writes. Ten milliseconds for a USB round trip fails spuriously on a loaded host
  or through a hub, and nothing retries behind it
- Restore the shift register when a self-test fails. The check returned on
  mismatch before putting the register back, so a failure made the *next* read
  disagree with the latched outputs. No relay moved either way

## Earlier releases

See the [git history](https://github.com/adriankumpf/arb-ex/commits/master).
