# Changelog

## Unreleased

- add `Astro.Kernel.Catalog`, the default NAIF generic kernel set in SPICE load
  order with each kernel's download URL and SPICE ID word check.
  `mix astro.kernels` downloads and validates exactly this set; the catalog
  changes between releases as NAIF publishes newer kernels
- **breaking:** states are `%Astro.State{position: {x, y, z}, velocity: {vx, vy, vz}}`
  structs (km and km/s) instead of six-element lists. `Astro.Ephemeris.spkezr/5`,
  `spkez/5`, and `spkgeo/4` return `{:ok, %Astro.State{}, lt}`;
  `Astro.Orbit.from_state/3` takes and `Astro.Orbit.state_at/2` returns an
  `Astro.State`. `oscelt/3` and `conics/2` are removed from `Astro.Ephemeris`:
  use `Astro.Orbit.from_state/3` and `Astro.Orbit.state_at/2`, which work with
  `%Astro.Orbit{}` instead of eight-element lists. `from_elements/1` and
  `to_elements/1` are removed from `Astro.Orbit`; build orbits from known
  elements with `%Astro.Orbit{rp: ..., ecc: ..., ...}` and read the fields
  directly
- **breaking:** `Astro.Orbit.osculating/4` raises `ArgumentError` for options
  other than `:frame`, `:abcorr`, and `:mu`; misspelled options were silently
  ignored. `Astro.Orbit` gains a `frame` field, set by `osculating/4` and `nil`
  for orbits built directly or with `from_state/3`
- ERFA date and time rejections in `Astro.Time` raise `ArgumentError` with a
  message naming the invalid calendar field and value (or the out-of-range
  Julian Date) instead of a bare `argument error`
- subtract J2000 from the larger part of the Julian date in
  `Astro.Time.day2sec/1`; small-first splits such as `{1.0e-9, 2451545.0}`
  previously lost the small part's precision
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
- stream kernel downloads to disk instead of buffering each body in memory
- **breaking:** `mix astro.kernels` and the dev config use current NAIF
  kernels instead of superseded ones: `de442.bsp` replaces `de440.bsp`,
  `L*_de441.bsp` replace `L*_de431.bsp`, `mar099.bsp` replaces `mar097.bsp`,
  `jup347`–`jup349` replace `jup344`/`jup346`, `sat455`–`sat480` replace
  `sat452`/`sat453`, `ura184_part-1`–`3` replace `ura111`/`ura115`/`ura116`,
  `nep098_part-1`–`3`, `nep104` and `nep105` replace `nep095`/`nep102`, and
  `plu060` replaces `plu058`. Every previously covered body is still covered,
  plus moons discovered since; the full download grows to about 15 GB. Update
  configured paths and rerun the task; old files are no longer loaded
- `mix astro.kernels` and the dev config add the lunar frame kernel
  `moon_de440_250416.tf`, without which the `MOON_PA`/`MOON_ME` frames of
  `moon_pa_de440_200625.bpc` are unknown, and NAIF's `*_nameid.tf` and
  `codes_300ast_20100725.tf` kernels, so satellites and asteroids whose names
  are not built into CSPICE N0067 resolve by name. With the asteroid kernel
  loaded, `Astro.Support.bodc2n/1` returns its names (`"1 CERES"`); built-in
  names such as `"CERES"` still resolve with `bodn2c/1`
- `mix astro.kernels` downloads `earth_latest_high_prec.bpc` again on every
  run; NAIF updates it about twice a week, and the task used to keep the
  first copy forever
- `mix astro.kernels` checks that every downloaded and existing file starts
  with the SPICE ID word of its kernel type (`DAF/SPK`, `KPL/FK`, ...). A
  download that is not a kernel, such as an HTML error page served with HTTP
  200, fails the task and is not kept; an existing file that is not a kernel
  is reported and downloaded again
- `mix astro.kernels` prints a `config/runtime.exs` snippet that resolves
  kernels with `Application.app_dir/2` instead of working-directory-relative
  paths, so configured kernels also load from releases
- **breaking:** `:req` is an optional dependency; add `{:req, "~> 0.7"}` to
  run `mix astro.kernels`. The task no longer starts `:ex_astro` (and loads
  every configured kernel) before downloading. `:ex_doc` is dev-only
- **breaking:** require Elixir 1.16 or newer; 1.15 no longer receives
  security patches
- **breaking:** require Erlang/OTP 25 or newer; finch 0.24, pulled in by the
  optional `req`, cannot start on OTP 24, which no longer receives patches

## v0.3.0 (2026-08-15)

- **breaking:** Julian Dates in `Astro.Time` are two-part `{jd1, jd2}` tuples
  instead of single floats (`to_datetime/1`, `jd2dt/1`, `dtf2d/6`, and every
  time-scale conversion). Wrap existing floats with `Astro.Time.jd_from_float/1`
  and collapse results with `Astro.Time.jd_to_float/1`
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
