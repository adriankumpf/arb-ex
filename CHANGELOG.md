# Changelog

## [0.20.0-rc.0] — unreleased

Tracks `arb` 0.8.0, which replaced its three free functions with a libusb
context and a board handle. This release passes that shape through to Elixir:
**every 0.19 entry point is gone.**

### Migrating from 0.19

Open a context once and keep it — that is where the release's saving lives.
`Arb.open/0` costs ~6.5 ms, almost entirely `libusb_init`; every other call
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
| —                                   | `Arb.open/0`, `Arb.board/2`, `Arb.boards/1`, `Arb.port/1`        |
| —                                   | `Arb.board_at/2` and `Arb.location/1` — name a board in config   |
| —                                   | `Arb.self_test/1`, the check `get_active/1` used to run silently |
| `:bad_device`                       | `:self_test_failed`                                              |
| `:verification_failed`              | `{:verification_failed, expected, actual}`                       |
| `{:io, msg}`                        | gone — no library path could produce it                          |
| —                                   | `:busy`, `{:invalid_relay, n}`, `{:unknown, msg}`                |

Who holds the context is now your decision, because a held context is **not
self-healing**: where 0.19 built a fresh one per call and therefore recovered
from a soured libusb state by accident, 0.20 does not. Keep it somewhere
swappable and open a new one after repeated failures. See `Arb.Usb`.

### Changed (**breaking**)

- Replace `activate/2`, `get_active/1` and `reset/1` with `set_relays/3`,
  `relays/1` and `reset_device/1`, taking an `Arb.Board` rather than a `:port`
  option. `reset/1` in particular read like "turn all the relays off"; it is a
  USB reset and leaves the relay outputs untouched
- Split the board's self-test out of the read. `get_active/1` performed a hidden
  read-modify-write — an inverted test pattern written to the shift register,
  read back and undone — that doubled its cost and was not mentioned by its name.
  The check is now `self_test/1`, and a read costs 28 USB transfers rather than
  56. **Callers that relied on reading to vet the board must call `self_test/1`
  themselves**
- Give `:verification_failed` the relay ids it expected and read back. It
  previously carried nothing, so a caller was told the read-back disagreed but
  not how
- Rename `:bad_device` to `:self_test_failed`
- Report a board held by another application as `:busy` rather than as
  `{:usb, "Resource busy"}`, which made it indistinguishable from a real USB
  fault even though it is normal and retryable on a shared board
- Validate `:port` as a byte rather than as any non-negative integer. `arb` takes
  a `u8`, so a larger number previously reached the NIF and failed to decode with
  an opaque `ArgumentError`

### Removed (**breaking**)

- The `{:io, message}` error reason, which no library path could produce

### Added

- `Arb.open/0` and `Arb.Usb`, the libusb context
- `Arb.board/2` and `Arb.Board`, a handle to one board. It holds a selector, not
  a device and not a USB claim, so it is free to build and never locks another
  application out of a shared board
- `Arb.boards/1`, which returns every attached board in a stable order. An
  enumerated board is named by where it sits on the USB tree rather than by port
  number, so it always resolves back to the board it came from. An empty list
  means no board is attached rather than `:not_found`
- `Arb.location/1` and `Arb.board_at/2`, which make that name something you can
  keep. A location is a string like `"1-1.3"` — the spelling `lsusb -t` uses —
  so the board `boards/1` found today can go in a configuration file and be
  named again after a restart. A port number cannot do that: it is unique only
  among one hub's ports, so two boards behind two hubs can share it. Parsing is
  the only thing `board_at/2` can fail at, which is the point — a mistyped
  location fails at startup rather than resolving to nothing at the first relay
  switch
- `Arb.port/1`, and an `Inspect` for `Arb.Board` that renders
  `#Arb.Board<port 3 (1-1.3)>` — enough to tell apart two boards that share a
  port number
- `Arb.self_test/1`, the read-back check `get_active/1` used to perform on the
  way past. It moves no relay, so it is safe to call on a live board
- `{:invalid_relay, n}`, `{:invalid_location, string}` and `{:unknown, message}`
  error reasons. The last is how a variant added to `arb`'s non-exhaustive error
  type reaches Elixir without the NIF failing to compile

### Fixed

Inherited from `arb` 0.8.0:

- Re-attach the kernel driver when the USB interface is released. It was
  previously detached on open and never restored
- Raise the USB bulk timeouts to 1000 ms, from 10 ms for reads and 100 ms for
  writes. Ten milliseconds for a USB round trip is tight enough to fail
  spuriously on a loaded host or through a hub, and nothing retries behind it
- Restore the shift register when a self-test fails. The check returned on
  mismatch before putting the register back, so a failure made the *next* read
  disagree with the latched outputs. No relay moved either way

## Earlier releases

See the [git history](https://github.com/adriankumpf/arb-ex/commits/master).
