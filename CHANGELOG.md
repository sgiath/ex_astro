# Changelog

## Unreleased

- decode UTC Julian Dates on leap-second days with their real day length;
  `jd2dt/1` returns second `60` and `to_datetime/1` raises for it
- replace the unguarded Kepler Newton iteration with a bisection-safeguarded
  solver; near-parabolic orbits no longer return divergent eccentric anomalies
- convert the documented observer `ut` seconds of `tt2tdb/5` and `tdb2tt/5`
  to the day fraction ERFA expects; the seconds were previously passed as days
- convert `DateTime` values by their UTC instant in `to_julian_date/1` and
  `to_et/1`; non-UTC offsets were previously ignored
- prefix SPICE error messages with their short code (`SPICE(...) -- ...`);
  `Astro.Support.spkobj/1` now grows past 1024 IDs as documented
- **breaking:** `Astro.Time.str2et/1`, `utc2et/1`, and `unitim/3` return
  `{:ok, value}`; they already returned `{:error, message}` on SPICE failures
  despite specs promising a bare float
- **breaking:** `Astro.Kernel.loaded/0` returns `{:ok, paths}` or
  `{:error, message}` like the other kernel operations instead of raising
- resolve the body name and read its values under one CSPICE lock in
  `Astro.Support.bodvrd/2`, so concurrent kernel changes cannot mix pool states
- decode fixed-length vector arguments cell by cell instead of measuring the
  whole list first, so oversized lists passed to normal-scheduler NIFs such as
  `Astro.Star.pvstar/1` are rejected without scanning them
- `mix astro.kernels` rejects non-200 responses and file errors, writes each
  kernel to a `.part` file renamed on success, and exits non-zero listing the
  failed downloads; previously error pages were saved as kernels and skipped
  forever after

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
