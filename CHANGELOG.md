# Changelog

## [Unreleased]

### Changed

- Breaking: `Arb.get_active/1` expects a keyword list with the `:port`

  ```elixir
  # Before
  Arb.get_active(port)

  # After
  Arb.get_active(port: port)
  ```

- Breaking: `Arb.reset/1` expects a keyword list with the `:port`

  ```elixir
  # Before
  Arb.reset(port)

  # After
  Arb.reset(port: port)
  ```

## [0.7.0-rc.2] - 2021-03-19

### Changed

- Clean up NIF implementation

### Fixed

- Run on dirty IO scheduler

## [0.7.0-rc.1] - 2021-03-19

### Fixed

- Fix return value of activate/2 and reset/1

## [0.7.0-rc.0] - 2021-03-19

### Changed

- Upgrade rustler to 0.22.0-rc.0
- Bump abacom-relay-board (arb) to 0.5.1

## [0.6.0] - 2019-12-20

### Changed

- Bump abacom-relay-board (arb) to 0.5.0

## [0.5.0] - 2019-09-24

### Added

- Support for OTP22

## [0.4.1] - 2019-05-23

### Changed

- Update dependencies

## [0.4.0] - 2019-01-06

### Added

- Run on dirty IO scheduler

### Changed

- Update dependencies

## [0.3.0] - 2019-01-06

### Changed

- Update `abacom-relay-board` to v0.3.0

### Removed

- Drop support for Rust 1.30 and below

## [0.2.3] - 2018-08-20

### Changed

- Update dependencies

## [0.2.2] - 2018-07-22

### Changed

- Update `rustler` to v0.17

## [0.2.1] - 2018-05-16

### Changed

- Update `abacom-relay-board` to v0.2.1

### Removed

- Drop support for Rust 1.25 and below

## [0.2.0] - 2018-04-08

### Added

- Introduce `Arb.reset/1` to reset a relay board

### Changed

- Improve build time by only installing library dependencies of `abacom-relay-board`

## [0.1.0] - 2018-03-31

[unreleased]: https://github.com/adriankumpf/arb-ex/compare/v0.7.0-rc.2...HEAD
[0.7.0-rc.1]: https://github.com/adriankumpf/arb-ex/compare/v0.7.0-rc.1...v0.7.0-rc.2
[0.7.0-rc.1]: https://github.com/adriankumpf/arb-ex/compare/v0.7.0-rc.0...v0.7.0-rc.1
[0.7.0-rc.0]: https://github.com/adriankumpf/arb-ex/compare/v0.6.0...v0.7.0-rc.0
[0.6.0]: https://github.com/adriankumpf/arb-ex/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/adriankumpf/arb-ex/compare/v0.4.1...v0.5.0
[0.4.1]: https://github.com/adriankumpf/arb-ex/compare/v0.4.0...v0.4.1
[0.4.0]: https://github.com/adriankumpf/arb-ex/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/adriankumpf/arb-ex/compare/v0.2.3...v0.3.0
[0.2.3]: https://github.com/adriankumpf/arb-ex/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/adriankumpf/arb-ex/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/adriankumpf/arb-ex/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/adriankumpf/arb-ex/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/adriankumpf/arb-ex/compare/fe9c436...v0.1.0
