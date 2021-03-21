use rustler::{Atom, NifTuple, NifUntaggedEnum};

#[derive(NifTuple, Debug)]
struct ErrorMessage(Atom, String);

#[derive(NifUntaggedEnum, Debug)]
enum Reason {
    Atom(Atom),
    Tuple(ErrorMessage),
}

impl Reason {
    fn new(reason: Atom) -> Self {
        Self::Atom(reason)
    }
    fn from_error(reason: Atom, error: impl std::error::Error) -> Self {
        Self::Tuple(ErrorMessage(reason, error.to_string()))
    }
}

impl From<arb::Error> for Reason {
    fn from(err: arb::Error) -> Self {
        mod atom {
            rustler::atoms! { not_found, multiple_found, verification_failed, unsafe_read, bad_device, usb, io }
        }

        match err {
            arb::Error::NotFound => Reason::new(atom::not_found()),
            arb::Error::MultipleFound => Reason::new(atom::multiple_found()),
            arb::Error::VerificationFailed => Reason::new(atom::verification_failed()),
            arb::Error::UnsafeRead => Reason::new(atom::unsafe_read()),
            arb::Error::BadDevice => Reason::new(atom::bad_device()),
            arb::Error::Usb(e) => Reason::from_error(atom::usb(), e),
            arb::Error::IO(e) => Reason::from_error(atom::io(), e),
        }
    }
}

#[rustler::nif(schedule = "DirtyIo", name = "__activate__")]
fn activate(relays: Vec<u8>, verify: bool, port: Option<u8>) -> Result<(), Reason> {
    let relays = relays
        .into_iter()
        .filter(|r| *r != 0)
        .fold(0, |acc, r| acc | 1 << (r - 1));

    Ok(arb::set_status(relays, verify, port)?)
}

#[rustler::nif(schedule = "DirtyIo", name = "__get_active__")]
fn get_active(port: Option<u8>) -> Result<Vec<u8>, Reason> {
    let result = arb::get_status(port)?;

    let active_relays = (0..8)
        .filter_map(|m| match (1 << m) & result != 0 {
            true => Some(m + 1),
            false => None,
        })
        .collect();

    Ok(active_relays)
}

#[rustler::nif(schedule = "DirtyIo", name = "__reset__")]
fn reset(port: Option<u8>) -> Result<(), Reason> {
    Ok(arb::reset(port)?)
}

rustler::init!("Elixir.Arb", [activate, get_active, reset]);
