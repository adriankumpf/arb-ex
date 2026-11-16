use arb::Verify;
use rustler::{Atom, NifException, NifStruct, NifUntaggedEnum, Resource, ResourceArc};

use crate::relays::{parse_relays, to_ids};

/// A libusb context, usable from any process on any scheduler.
struct UsbResource(arb::Usb);

#[rustler::resource_impl]
impl Resource for UsbResource {}

/// One relay board. Holds a selector, not an open device and not a USB claim.
struct BoardResource(arb::Board);

#[rustler::resource_impl]
impl Resource for BoardResource {}

/// Encode-only: the NIFs below take the `reference` field, which Elixir unwraps,
/// rather than decoding the whole struct to reach it.
#[derive(NifStruct)]
#[module = "Arb.Usb"]
struct UsbTerm {
    reference: ResourceArc<UsbResource>,
}

/// Encode-only, as [`UsbTerm`].
#[derive(NifStruct)]
#[module = "Arb.Board"]
struct BoardTerm {
    reference: ResourceArc<BoardResource>,
    port: Option<u8>,
}

impl BoardTerm {
    fn new(board: arb::Board) -> Self {
        Self {
            port: board.port(),
            reference: ResourceArc::new(BoardResource(board)),
        }
    }
}

#[derive(NifUntaggedEnum, Debug)]
enum Reason {
    Atom(Atom),
    Message((Atom, String)),
    Verification((Atom, Vec<u8>, Vec<u8>)),
}

#[derive(NifException, Debug)]
#[module = "Arb.Error"]
struct ArbError {
    reason: Reason,
    /// `arb`'s own rendering, carried across so that `Arb.Error.message/1` has
    /// no second copy of these strings to drift from when the pinned revision
    /// moves.
    message: String,
}

impl From<arb::Error> for ArbError {
    fn from(err: arb::Error) -> Self {
        mod atom {
            rustler::atoms! {
                not_found,
                multiple_found,
                busy,
                verification_failed,
                unexpected_transfer_length,
                register_out_of_sync,
                self_test_failed,
                usb,
                unknown
            }
        }

        // `arb::Error::Usb` renders as the bare `rusb` message, which alone does
        // not say which layer produced it. Every other variant already reads as a
        // whole sentence.
        let message = match &err {
            arb::Error::Usb(err) => format!("libusb error: {err}"),
            err => err.to_string(),
        };

        let reason = match err {
            arb::Error::NotFound => Reason::Atom(atom::not_found()),
            arb::Error::MultipleFound => Reason::Atom(atom::multiple_found()),
            arb::Error::Busy => Reason::Atom(atom::busy()),
            arb::Error::SelfTestFailed => Reason::Atom(atom::self_test_failed()),
            arb::Error::VerificationFailed { expected, actual } => Reason::Verification((
                atom::verification_failed(),
                to_ids(expected),
                to_ids(actual),
            )),
            err @ arb::Error::UnexpectedTransferLength { .. } => {
                Reason::Message((atom::unexpected_transfer_length(), err.to_string()))
            }
            // The payload is the transport failure underneath, not the whole
            // rendering: the sentence around it is already in `message`, and what
            // a log wants from here is the cause `Error::source` would give.
            arb::Error::RegisterOutOfSync { source } => {
                Reason::Message((atom::register_out_of_sync(), source.to_string()))
            }
            arb::Error::Usb(err) => Reason::Message((atom::usb(), err.to_string())),
            // `arb::Error` is `#[non_exhaustive]`: a variant added upstream must
            // still reach Elixir as something `Arb.Error.message/1` can render,
            // rather than failing to compile the NIF or being silently dropped.
            // `InvalidRelay` also lands here — `Arb.set_relays/3` has already
            // rejected those, so one arriving means a bug rather than bad input.
            err => Reason::Message((atom::unknown(), err.to_string())),
        };

        Self { reason, message }
    }
}

/// Dirty IO: ~6.5 ms, far past what a scheduler may be held for.
#[rustler::nif(schedule = "DirtyIo")]
fn open() -> Result<UsbTerm, ArbError> {
    Ok(UsbTerm {
        reference: ResourceArc::new(UsbResource(arb::Usb::new()?)),
    })
}

/// Resolves nothing and touches no hardware, so it stays on a normal scheduler.
#[rustler::nif]
fn board(usb: ResourceArc<UsbResource>, port: Option<u8>) -> BoardTerm {
    BoardTerm::new(usb.0.board(port))
}

/// `arb`'s own rendering — `any board`, `port 3`, or `port 3 (1-1.3)` for an
/// enumerated board, the last being the only thing that tells apart two boards
/// sharing a port number.
///
/// Called from `Arb.Board`'s `Inspect` rather than stored on the struct: only
/// inspection needs it, and `Arb.board/2` is meant to be free to build. It
/// formats already-resolved data, so it too stays on a normal scheduler.
#[rustler::nif]
fn describe(board: ResourceArc<BoardResource>) -> String {
    board.0.to_string()
}

// The operations below enumerate the USB bus, claim the interface and run bulk
// transfers with a 1 s timeout apiece: 28 for a read, 56 for a verified write or
// a self-test. So while the typical call is ~50 µs, an unresponsive board can
// hold the caller for half a minute. That worst case is what puts them on dirty
// IO — and it is worth bounding how many run at once, since the dirty IO pool is
// shared with the rest of the VM.

#[rustler::nif(schedule = "DirtyIo")]
fn boards(usb: ResourceArc<UsbResource>) -> Result<Vec<BoardTerm>, ArbError> {
    Ok(usb.0.boards()?.into_iter().map(BoardTerm::new).collect())
}

#[rustler::nif(schedule = "DirtyIo")]
fn set_relays(
    board: ResourceArc<BoardResource>,
    ids: Vec<u8>,
    verify: bool,
) -> Result<(), ArbError> {
    let verify = if verify {
        Verify::Enabled
    } else {
        Verify::Disabled
    };

    Ok(board.0.set_relays(parse_relays(ids)?, verify)?)
}

#[rustler::nif(schedule = "DirtyIo")]
fn relays(board: ResourceArc<BoardResource>) -> Result<Vec<u8>, ArbError> {
    Ok(to_ids(board.0.relays()?))
}

/// Returns the relays the check found active on its way past: it has to read the
/// register before it can write its test pattern, so the verdict and the state
/// come out of one claim.
#[rustler::nif(schedule = "DirtyIo")]
fn self_test(board: ResourceArc<BoardResource>) -> Result<Vec<u8>, ArbError> {
    Ok(to_ids(board.0.self_test()?))
}

#[rustler::nif(schedule = "DirtyIo")]
fn reset_device(board: ResourceArc<BoardResource>) -> Result<(), ArbError> {
    Ok(board.0.reset_device()?)
}

rustler::init!("Elixir.Arb.Native");
