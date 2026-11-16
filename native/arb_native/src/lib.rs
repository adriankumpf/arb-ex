mod relays;

// Left out of test builds: the NIF code calls the enif_* functions, which only
// the BEAM provides when it loads the library. A test executable has nothing to
// resolve them against and fails to link (or, with rust-lld, to load).
#[cfg(not(test))]
mod nif;
