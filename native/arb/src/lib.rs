use rustler::{Atom, NifStruct, NifTuple, NifUntaggedEnum};

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
        Self::Tuple(ErrorMessage(reason, format!("{}", error)))
    }
}

impl From<arb::Error> for Reason {
    fn from(err: arb::Error) -> Self {
        mod atom {
            rustler::atoms! { not_found, multiple_found, verification_failed, unsafe_read, bad_device, usb, io, }
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

#[derive(NifStruct)]
#[module = "Arb.Native.Options"]
struct Options {
    port: Option<u8>,
    verify: bool,
}

#[rustler::nif(schedule = "DirtyCpu", name = "__activate__")]
fn activate(relays: Vec<u8>, options: Options) -> Result<(), Reason> {
    let relays = relays
        .into_iter()
        .filter(|&r| r != 0)
        .fold(0, |acc, r| acc | 1 << (r - 1));

    Ok(arb::set_status(relays, options.verify, options.port)?)
}

#[rustler::nif(schedule = "DirtyCpu", name = "__get_active__")]
fn get_active(port: Option<u8>) -> Result<Vec<u8>, Reason> {
    let result = arb::get_status(port)?;

    let active_relays = (0..8)
        .filter_map(|m| {
            if (1 << m) & result != 0 {
                Some(m + 1)
            } else {
                None
            }
        })
        .collect();

    Ok(active_relays)
}

#[rustler::nif(schedule = "DirtyCpu", name = "__reset__")]
fn reset(port: Option<u8>) -> Result<(), Reason> {
    Ok(arb::reset(port)?)
}

rustler::init!("Elixir.Arb.Native", [activate, get_active, reset]);
