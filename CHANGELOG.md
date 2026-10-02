# Changelog

## Unreleased

- decode UTC Julian Dates on leap-second days with their real day length;
  `jd2dt/1` returns second `60` and `to_datetime/1` raises for it

## v0.3.0 (2026-08-15)

- add high-level orbit, ephemeris-time, and gravitational-parameter helpers
- add `Astro.Star` catalog propagation and BCRS state-vector conversions with auditable ERFA warnings
- serialize CSPICE-backed NIF access to prevent concurrent kernel/error-state races
- run blocking SPICE-backed NIFs on dirty schedulers to protect BEAM scheduler responsiveness
- harden native string input handling against embedded NULs and oversized binaries
- normalize Julian-date datetime rounding across midnight to avoid invalid hour 24 values
- remove hidden SPICE support result caps for `spkobj`, `bodvcd`, and `bodvrd`
- tighten shared native utility include, allocation, and warning hygiene
- consolidate native wrappers into one NIF with a single atomic CSPICE kernel pool
- vendor the CSPICE N0067 Linux headers and static libraries for offline builds
- convert the solar-system and nearby-stars examples into Livebooks
- restructure the example Livebooks into staged tutorials with interleaved
  theory, per-function breakdowns, and intermediate SVG renders

## v0.2.2 (2024-10-01)

- updated Elixir dependencies
- added Nix Flake setup

## v0.2.1 (2024-01-07)

- fix loading strings
- new functions
  - `bodvrd`

## v0.2.0 (2024-01-07)

- standardize all functions outputs to be same as in SPICE
- return :ok/:error tuples
- new functions
  - `bodvcd`
  - `oscelt`
  - `conics`
- more documentation

## v0.1.0 (2024-01-03)

- initial release
