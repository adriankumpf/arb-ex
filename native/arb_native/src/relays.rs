//! The relay id mapping, free of rustler types so its tests run outside the
//! BEAM.

/// Relay ids to a relay set.
pub(crate) fn parse_relays(ids: Vec<u8>) -> Result<arb::Relays, arb::Error> {
    ids.into_iter().map(arb::Relay::try_from).collect()
}

pub(crate) fn to_ids(relays: arb::Relays) -> Vec<u8> {
    relays.iter().map(|relay| relay.number()).collect()
}

#[cfg(test)]
mod tests {
    use super::*;

    /// The relay-number-to-bit mapping, spelled out, in both directions.
    ///
    /// `arb` owns this mapping and tests it too, so what these pin is the
    /// *pinned revision*: the dependency moves by `rev`, and nothing else here
    /// would notice a renumbering. The Elixir suite has no board to read back
    /// from, so an off-by-one would first show up as the wrong relay closing.
    #[test]
    fn relay_ids_map_to_the_documented_bits() {
        assert_eq!(parse_relays(vec![1]).unwrap().bits(), 0b0000_0001);
        assert_eq!(parse_relays(vec![8]).unwrap().bits(), 0b1000_0000);
        assert_eq!(parse_relays(vec![1, 3]).unwrap().bits(), 0b0000_0101);
        assert_eq!(parse_relays(vec![]).unwrap().bits(), 0b0000_0000);

        // Exact, ordered comparisons: `Arb.relays/1` promises ascending ids.
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
    fn one_bad_id_rejects_the_whole_set() {
        // The part `parse_relays` actually owns: collecting into a `Result` so a
        // partial write cannot latch relays the caller did not ask for.
        assert!(parse_relays(vec![1, 9]).is_err());
        assert!(matches!(
            parse_relays(vec![9]),
            Err(arb::Error::InvalidRelay(9))
        ));
    }
}
