use rustler::{Atom, NifException, NifTuple, NifUntaggedEnum};

#[derive(NifTuple, Debug)]
struct ErrorTuple(Atom, String);

#[derive(NifUntaggedEnum, Debug)]
enum Reason {
    Atom(Atom),
    Tuple(ErrorTuple),
}

#[derive(NifException, Debug)]
#[module = "Arb.Error"]
struct ArbError {
    reason: Reason,
}

impl ArbError {
    pub fn new(reason: Atom) -> Self {
        Self {
            reason: Reason::Atom(reason),
        }
    }
    fn from_error(reason: Atom, error: impl std::error::Error) -> Self {
        Self {
            reason: Reason::Tuple(ErrorTuple(reason, error.to_string())),
        }
    }
}

impl From<arb::Error> for ArbError {
    fn from(err: arb::Error) -> Self {
        mod atom {
            rustler::atoms! { not_found, multiple_found, verification_failed, bad_device, usb, io }
        }

        match err {
            arb::Error::NotFound => ArbError::new(atom::not_found()),
            arb::Error::MultipleFound => ArbError::new(atom::multiple_found()),
            arb::Error::VerificationFailed => ArbError::new(atom::verification_failed()),
            arb::Error::BadDevice => ArbError::new(atom::bad_device()),
            arb::Error::Usb(e) => ArbError::from_error(atom::usb(), e),
            arb::Error::IO(e) => ArbError::from_error(atom::io(), e),
        }
    }
}

#[rustler::nif(schedule = "DirtyIo", name = "__activate__")]
fn activate(relays: Vec<u8>, verify: bool, port: Option<u8>) -> Result<(), ArbError> {
    let relays = relays
        .into_iter()
        .filter(|r| *r != 0)
        .fold(0, |acc, r| acc | 1 << (r - 1));

    Ok(arb::set_status(relays, verify, port)?)
}

#[rustler::nif(schedule = "DirtyIo", name = "__get_active__")]
fn get_active(port: Option<u8>) -> Result<Vec<u8>, ArbError> {
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
fn reset(port: Option<u8>) -> Result<(), ArbError> {
    Ok(arb::reset(port)?)
}

rustler::init!("Elixir.Arb");
