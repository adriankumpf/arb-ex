use arb;

use rustler::types::atom;
use rustler::{Encoder, Env, NifResult, NifStruct, Term};

mod reason {
    rustler::atoms! {
        not_found,
        multiple_found,
        verification_failed,
        unsafe_read,
        bad_device,
        usb,
        io,
    }
}

#[derive(NifStruct)]
#[module = "Arb.Native.Options"]
struct Options {
    pub port: Option<u8>,
    pub verify: bool,
}

fn arb_error_to_term<'a>(env: Env<'a>, err: arb::Error) -> Term<'a> {
    let reason = match err {
        arb::Error::NotFound => reason::not_found().encode(env),
        arb::Error::MultipleFound => reason::multiple_found().encode(env),
        arb::Error::VerificationFailed => reason::verification_failed().encode(env),
        arb::Error::UnsafeRead => reason::unsafe_read().encode(env),
        arb::Error::BadDevice => reason::bad_device().encode(env),
        arb::Error::Usb(reason) => (reason::usb(), format!("{}", reason).encode(env)).encode(env),
        arb::Error::IO(reason) => (reason::io(), format!("{}", reason).encode(env)).encode(env),
    };

    (atom::error(), reason).encode(env)
}

#[rustler::nif(schedule = "DirtyCpu")]
fn activate<'a>(env: Env<'a>, relays: Vec<u8>, options: Options) -> NifResult<Term<'a>> {
    let relays: u8 = relays
        .into_iter()
        .filter(|&r| r != 0)
        .fold(0, |acc, r| acc | 1 << (r - 1));

    match arb::set_status(relays, options.verify, options.port) {
        Err(err) => Ok(arb_error_to_term(env, err)),
        Ok(()) => Ok(atom::ok().encode(env)),
    }
}

#[rustler::nif(schedule = "DirtyCpu")]
fn get_active<'a>(env: Env<'a>, port: Option<u8>) -> NifResult<Term<'a>> {
    let result = match arb::get_status(port) {
        Err(err) => return Ok(arb_error_to_term(env, err)),
        Ok(inner) => inner,
    };

    let active_relays: Vec<u8> = (0..8)
        .filter_map(|m| {
            if (1 << m) & result != 0 {
                Some(m + 1)
            } else {
                None
            }
        })
        .collect();

    Ok((atom::ok(), active_relays).encode(env))
}

#[rustler::nif(schedule = "DirtyCpu")]
fn reset<'a>(env: Env<'a>, port: Option<u8>) -> NifResult<Term<'a>> {
    match arb::reset(port) {
        Err(err) => return Ok(arb_error_to_term(env, err)),
        Ok(()) => Ok(atom::ok().encode(env)),
    }
}

rustler::init!("Elixir.Arb.Native", [activate, get_active, reset]);
