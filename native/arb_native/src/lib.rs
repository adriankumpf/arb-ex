use rustler::{Atom, NifException, NifStruct, NifUntaggedEnum, Resource, ResourceArc};

// ---------------------------------------------------------------------------
// Resources
// ---------------------------------------------------------------------------

/// A libusb context. `arb::Usb::new` is ~6.5 ms — almost all of it `libusb_init` —
/// and every other call is ~50 µs, so the context is built once and held by the
/// caller for the lifetime of the node. It is `Send + Sync`, so any process may
/// use it from any scheduler.
struct UsbResource(arb::Usb);

#[rustler::resource_impl]
impl Resource for UsbResource {}

/// One relay board. Holds a selector, not a device and not a USB claim, so it is
/// free to build and never locks another application out of a shared board.
struct BoardResource(arb::Board);

#[rustler::resource_impl]
impl Resource for BoardResource {}

#[derive(NifStruct)]
#[module = "Arb.Usb"]
struct UsbTerm {
    reference: ResourceArc<UsbResource>,
}

#[derive(NifStruct)]
#[module = "Arb.Board"]
struct BoardTerm {
    reference: ResourceArc<BoardResource>,
    /// The board's port on its parent hub, or `nil` for "whichever board is
    /// attached". A label rather than an identifier: it is unique only among one
    /// hub's ports.
    port: Option<u8>,
    /// `arb`'s own rendering — `port 3 (bus 1, path 1.3)` — which is the only
    /// thing that tells apart two boards sharing a port number.
    description: String,
}

impl BoardTerm {
    fn new(board: arb::Board) -> Self {
        Self {
            port: board.port(),
            description: board.to_string(),
            reference: ResourceArc::new(BoardResource(board)),
        }
    }
}

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

#[derive(NifUntaggedEnum, Debug)]
enum Reason {
    Atom(Atom),
    Message(MessageTuple),
    Relay(RelayTuple),
    Verification(VerificationTuple),
}

#[derive(rustler::NifTuple, Debug)]
struct MessageTuple(Atom, String);

#[derive(rustler::NifTuple, Debug)]
struct RelayTuple(Atom, u8);

#[derive(rustler::NifTuple, Debug)]
struct VerificationTuple(Atom, Vec<u8>, Vec<u8>);

#[derive(NifException, Debug)]
#[module = "Arb.Error"]
struct ArbError {
    reason: Reason,
}

impl ArbError {
    fn atom(reason: Atom) -> Self {
        Self {
            reason: Reason::Atom(reason),
        }
    }

    fn message(reason: Atom, error: impl std::fmt::Display) -> Self {
        Self {
            reason: Reason::Message(MessageTuple(reason, error.to_string())),
        }
    }
}

impl From<arb::Error> for ArbError {
    fn from(err: arb::Error) -> Self {
        mod atom {
            rustler::atoms! {
                not_found,
                multiple_found,
                busy,
                verification_failed,
                invalid_relay,
                unexpected_transfer_length,
                self_test_failed,
                usb,
                unknown
            }
        }

        match err {
            arb::Error::NotFound => ArbError::atom(atom::not_found()),
            arb::Error::MultipleFound => ArbError::atom(atom::multiple_found()),
            arb::Error::Busy => ArbError::atom(atom::busy()),
            arb::Error::SelfTestFailed => ArbError::atom(atom::self_test_failed()),
            arb::Error::VerificationFailed { expected, actual } => ArbError {
                reason: Reason::Verification(VerificationTuple(
                    atom::verification_failed(),
                    to_ids(expected),
                    to_ids(actual),
                )),
            },
            arb::Error::InvalidRelay(relay) => ArbError {
                reason: Reason::Relay(RelayTuple(atom::invalid_relay(), relay)),
            },
            err @ arb::Error::UnexpectedTransferLength { .. } => {
                ArbError::message(atom::unexpected_transfer_length(), err)
            }
            arb::Error::Usb(err) => ArbError::message(atom::usb(), err),
            // `arb::Error` is `#[non_exhaustive]`: a variant added upstream must
            // still reach Elixir as something `Arb.Error.message/1` can render,
            // rather than failing to compile the NIF or being silently dropped.
            ref err => ArbError::message(atom::unknown(), err),
        }
    }
}

// ---------------------------------------------------------------------------
// Relay conversion
// ---------------------------------------------------------------------------

/// Relay ids to a relay set.
///
/// Kept free of rustler types so the tests below can exercise it outside the
/// BEAM: `ArbError` builds atoms, which need a running VM.
fn parse_relays(ids: Vec<u8>) -> Result<arb::Relays, arb::Error> {
    ids.into_iter().map(arb::Relay::try_from).collect()
}

fn to_relays(ids: Vec<u8>) -> Result<arb::Relays, ArbError> {
    // `Arb.set_relays/3` rejects out-of-range ids with an `ArgumentError` before
    // it gets here, so in practice this only re-validates. It is the boundary
    // that must hold, though, and `arb::Error::InvalidRelay` is the honest answer
    // for anything that reaches the NIF another way.
    Ok(parse_relays(ids)?)
}

fn to_ids(relays: arb::Relays) -> Vec<u8> {
    relays.iter().map(|relay| relay.number()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The relay-number-to-bit mapping, spelled out. Nothing else in this crate
    /// can catch an off-by-one here: the Elixir suite has no board to read back
    /// from, so a mis-numbered relay would first show up as the wrong garage
    /// door opening.
    #[test]
    fn relay_ids_map_to_the_documented_bits() {
        assert_eq!(parse_relays(vec![1]).unwrap().bits(), 0b0000_0001);
        assert_eq!(parse_relays(vec![8]).unwrap().bits(), 0b1000_0000);
        assert_eq!(parse_relays(vec![1, 3]).unwrap().bits(), 0b0000_0101);
        assert_eq!(parse_relays(vec![]).unwrap().bits(), 0b0000_0000);
        assert_eq!(
            parse_relays((1..=8).collect::<Vec<u8>>()).unwrap().bits(),
            0b1111_1111
        );
    }

    #[test]
    fn bits_map_back_to_the_same_relay_ids() {
        assert_eq!(to_ids(arb::Relays::from_bits(0b0000_0001)), vec![1]);
        assert_eq!(to_ids(arb::Relays::from_bits(0b1000_0000)), vec![8]);
        assert_eq!(to_ids(arb::Relays::from_bits(0b1010_0001)), vec![1, 6, 8]);
        assert_eq!(to_ids(arb::Relays::NONE), Vec::<u8>::new());
        assert_eq!(to_ids(arb::Relays::ALL), (1..=8).collect::<Vec<u8>>());
    }

    #[test]
    fn ids_survive_a_round_trip() {
        for bits in 0..=u8::MAX {
            let relays = arb::Relays::from_bits(bits);
            assert_eq!(parse_relays(to_ids(relays)).unwrap().bits(), bits);
        }
    }

    #[test]
    fn ids_are_returned_in_ascending_order() {
        // `Arb.relays/1` promises a sorted list; a consumer comparing it against
        // a sorted expectation would otherwise flap.
        let ids = to_ids(arb::Relays::from_bits(0b1101_0110));
        let mut sorted = ids.clone();
        sorted.sort_unstable();

        assert_eq!(ids, sorted);
    }

    #[test]
    fn out_of_range_ids_are_rejected() {
        for id in [0, 9, 10, 255] {
            assert!(
                matches!(parse_relays(vec![id]), Err(arb::Error::InvalidRelay(got)) if got == id),
                "relay {id} should be rejected"
            );
        }

        // One bad id poisons the whole set rather than being dropped: a partial
        // write would latch relays the caller did not ask for.
        assert!(parse_relays(vec![1, 9]).is_err());
    }

    #[test]
    fn repeated_ids_are_idempotent() {
        assert_eq!(parse_relays(vec![3, 3, 3]).unwrap().bits(), 0b0000_0100);
    }
}

// ---------------------------------------------------------------------------
// NIFs
// ---------------------------------------------------------------------------

/// Dirty IO: ~6.5 ms, far past what a scheduler may be held for.
#[rustler::nif(schedule = "DirtyIo", name = "__open__")]
fn open() -> Result<UsbTerm, ArbError> {
    Ok(UsbTerm {
        reference: ResourceArc::new(UsbResource(arb::Usb::new()?)),
    })
}

/// Resolves nothing and touches no hardware, so it stays on a normal scheduler.
#[rustler::nif(name = "__board__")]
fn board(usb: UsbTerm, port: Option<u8>) -> BoardTerm {
    BoardTerm::new(usb.reference.0.board(port))
}

#[rustler::nif(schedule = "DirtyIo", name = "__boards__")]
fn boards(usb: UsbTerm) -> Result<Vec<BoardTerm>, ArbError> {
    Ok(usb
        .reference
        .0
        .boards()?
        .into_iter()
        .map(BoardTerm::new)
        .collect())
}

#[rustler::nif(schedule = "DirtyIo", name = "__set_relays__")]
fn set_relays(board: BoardTerm, ids: Vec<u8>, verify: bool) -> Result<(), ArbError> {
    let verify = match verify {
        true => arb::Verify::Enabled,
        false => arb::Verify::Disabled,
    };

    Ok(board.reference.0.set_relays(to_relays(ids)?, verify)?)
}

#[rustler::nif(schedule = "DirtyIo", name = "__relays__")]
fn relays(board: BoardTerm) -> Result<Vec<u8>, ArbError> {
    Ok(to_ids(board.reference.0.relays()?))
}

#[rustler::nif(schedule = "DirtyIo", name = "__self_test__")]
fn self_test(board: BoardTerm) -> Result<(), ArbError> {
    Ok(board.reference.0.self_test()?)
}

#[rustler::nif(schedule = "DirtyIo", name = "__reset_device__")]
fn reset_device(board: BoardTerm) -> Result<(), ArbError> {
    Ok(board.reference.0.reset_device()?)
}

rustler::init!("Elixir.Arb");
