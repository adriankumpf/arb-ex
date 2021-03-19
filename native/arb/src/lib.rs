use arb;

use rustler::{Atom, NifStruct, NifTuple, NifUntaggedEnum};

#[derive(NifTuple, Debug)]
pub struct ErrorTuple(Atom, String);

#[derive(NifUntaggedEnum, Debug)]
enum ArbError {
    Plain(Atom),
    Extended(ErrorTuple),
}

impl From<arb::Error> for ArbError {
    fn from(err: arb::Error) -> Self {
        mod reason {
            rustler::atoms! { not_found, multiple_found, verification_failed, unsafe_read, bad_device, usb, io, }
        }

        match err {
            arb::Error::NotFound => ArbError::Plain(reason::not_found()),
            arb::Error::MultipleFound => ArbError::Plain(reason::multiple_found()),
            arb::Error::VerificationFailed => ArbError::Plain(reason::verification_failed()),
            arb::Error::UnsafeRead => ArbError::Plain(reason::unsafe_read()),
            arb::Error::BadDevice => ArbError::Plain(reason::bad_device()),
            arb::Error::Usb(e) => ArbError::Extended(ErrorTuple(reason::usb(), format!("{}", e))),
            arb::Error::IO(e) => ArbError::Extended(ErrorTuple(reason::io(), format!("{}", e))),
        }
    }
}

#[derive(NifStruct)]
#[module = "Arb.Native.Options"]
struct Options {
    port: Option<u8>,
    verify: bool,
}

#[rustler::nif(schedule = "DirtyCpu")]
fn activate(relays: Vec<u8>, options: Options) -> Result<(), ArbError> {
    let relays = relays
        .into_iter()
        .filter(|&r| r != 0)
        .fold(0, |acc, r| acc | 1 << (r - 1));

    Ok(arb::set_status(relays, options.verify, options.port)?)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn get_active(port: Option<u8>) -> Result<Vec<u8>, ArbError> {
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

#[rustler::nif(schedule = "DirtyCpu")]
fn reset(port: Option<u8>) -> Result<(), ArbError> {
    Ok(arb::reset(port)?)
}

rustler::init!("Elixir.Arb.Native", [activate, get_active, reset]);
