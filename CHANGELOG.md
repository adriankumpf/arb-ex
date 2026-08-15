# Changelog

## [0.20.0-beta.1] — unreleased

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
  way past. It moves no relay, so it is safe to call on a live board, and it
  returns `{:ok, ids}`, the relays it found while checking. The check has to read
  the register before it can write its test pattern, so a caller wanting both a
  verdict and a state gets them from one claim instead of following it with
  `relays/1`
- `Arb.Error.retry_in_place?/1` — which reasons are worth another attempt as
  they stand, so a caller no longer re-encodes that list and goes a release out
  of date. It takes a bare reason as well as an `%Arb.Error{}`, for callers that
  cannot match the struct
- The `{:unknown, message}` error reason, which is how a variant added to `arb`'s
  non-exhaustive error type reaches Elixir
- The `{:register_out_of_sync, cause}` error reason, for a read that could not
  put the shift register back (see *Fixed*). No relay moved, but the board's
  account of them is gone, so a later `relays/1` can succeed and report nothing
  active on a board driving eight live outputs. It is the one failure where
  retrying the read is the wrong answer; `set_relays/3` writes the register and
  the outputs together again
- `t:Arb.board_option/0` and `t:Arb.set_relays_option/0`, so the accepted option
  values are visible in the specs
- **Precompiled NIFs.** Installing `:arb` no longer requires the Rust toolchain,
  and no longer requires `libusb` either — libusb is compiled from the copy the
  crate vendors and linked into the artifact, so nothing is expected of the host.
  Artifacts are published for Linux `x86_64`/`aarch64` (glibc and musl) and
  `armv7` (glibc), and for macOS `aarch64`/`x86_64`. Anywhere else it falls back
  to building from source, which needs Rust and a C compiler. `ARB_BUILD=true`
  forces that build on a supported target too

### Fixed

Inherited from `arb` 0.8.0:

- Re-attach the kernel driver when the USB interface is released. It was
  previously detached on open and never restored
- Raise the USB bulk timeouts to 1000 ms, from 10 ms for reads and 100 ms for
  writes. Ten milliseconds for a USB round trip fails spuriously on a loaded host
  or through a hub, and nothing retries behind it
- Put the shift register back on every path out of a read, failures included.
  Reading it clocks zeros in, so every read writes back what it read; a USB error
  between the two halves left the register holding zeros while the outputs held
  relays. Retrying, the documented remedy for a transient USB error, is what made
  it stick: the retried read succeeded and answered `{:ok, []}` for an energized
  board. Where the contents are genuinely gone the caller now gets
  `{:register_out_of_sync, cause}` instead of the transport error that invited
  the retry
- Restore the shift register when a self-test fails. The check returned on
  mismatch before putting the register back, so a failure made the *next* read
  disagree with the latched outputs. No relay moved either way
- Put the *latched* value back into the shift register after a failed
  verification, rather than the value that was read back. A mismatch implicates
  the read path, so leaving its answer in the register made the next read agree
  with the fault instead of with the relays

## Earlier releases

See the [git history](https://github.com/adriankumpf/arb-ex/commits/master).
