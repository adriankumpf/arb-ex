#[macro_use]
extern crate lazy_static;
#[macro_use]
extern crate rustler;
#[macro_use]
extern crate rustler_codegen;

extern crate arb;

use rustler::{NifEncoder, NifEnv, NifResult, NifTerm, types::NifListIterator};

mod atoms {
    rustler_atoms! {
        atom ok;
        atom error;

        atom not_found;
        atom multiple_found;
        atom verification_failed;
        atom unsafe_read;
        atom bad_device;
        atom usb;

        //atom __true__ = "true";
        //atom __false__ = "false";
    }
}

#[derive(NifStruct)]
#[module = "Arb.Native.Options"]
struct Options {
    pub port: Option<u8>,
    pub verify: bool,
}

fn arb_error_to_term<'a>(env: NifEnv<'a>, err: arb::Error) -> NifTerm<'a> {
    use arb::Error;

    let error = match err {
        Error::NotFound => atoms::not_found().encode(env),
        Error::MultipleFound => atoms::multiple_found().encode(env),
        Error::VerificationFailed => atoms::verification_failed().encode(env),
        Error::UnsafeRead => atoms::unsafe_read().encode(env),
        Error::BadDevice => atoms::bad_device().encode(env),
        Error::Usb(ref libusb_error) => {
            (atoms::usb(), format!("{}", libusb_error).encode(env)).encode(env)
        }
    };

    (atoms::error(), error).encode(env)
}

fn activate<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let list_iterator: NifListIterator = args[0].decode()?;
    let result: NifResult<Vec<u8>> = list_iterator
        .map(|x| x.decode::<u8>())
        .collect::<NifResult<Vec<u8>>>();

    let relays: u8 = result?
        .iter()
        .map(|&r| r as u8)
        .filter(|&r| r != 0)
        .fold(0, |acc, r| acc | 1 << (r - 1));

    let options: Options = args[1].decode()?;

    match arb::set_status(relays, options.verify, options.port) {
        Err(err) => Ok(arb_error_to_term(env, err)),
        Ok(()) => Ok(atoms::ok().encode(env)),
    }
}

fn get_active<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let port: Option<u8> = args[0].decode()?;

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

    Ok((atoms::ok(), active_relays).encode(env))
}

fn reset<'a>(env: NifEnv<'a>, args: &[NifTerm<'a>]) -> NifResult<NifTerm<'a>> {
    let port: Option<u8> = args[0].decode()?;

    match arb::reset(port) {
        Err(err) => return Ok(arb_error_to_term(env, err)),
        Ok(()) => Ok(atoms::ok().encode(env)),
    }
}

rustler_export_nifs! {
    "Elixir.Arb.Native",
    [
        ("activate", 2, activate),
        ("get_active", 1, get_active),
        ("reset", 1, reset)
    ],
    None
}
