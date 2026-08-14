# Astro

Library to help working with [SPICE](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/index.html)
and [ERFA](https://github.com/liberfa/erfa) libraries

<p align="center">
  <img src="https://raw.githubusercontent.com/sgiath/ex_astro/master/examples/inner-system.svg" width="49%" alt="Inner solar system with the main asteroid belt, true scale"/>
  <img src="https://raw.githubusercontent.com/sgiath/ex_astro/master/examples/solar-system.svg" width="49%" alt="The nine planets, radially compressed"/>
</p>

Real osculating orbits at a real epoch, drawn from JPL DE440 ephemerides by
[`examples/orbits.exs`](https://github.com/sgiath/ex_astro/blob/master/examples/orbits.exs) —
see the [example walkthrough](examples/README.md).

## Installation

It is a bit more complicated then normal lib so pay attention:

- instal ERFA library
  - <https://github.com/liberfa/erfa?tab=readme-ov-file#building-and-installing-erfa>
- add `ex_astro` to `mix.exs`

```elixir
  def deps do
    [
      ...
      {:ex_astro, "~> 0.3"},
      ...
    ]
  end
```

- download SPICE kernels; applications load configured paths when they start

```bash
mix astro.kernels
```

## Kernels

Configure kernels that should load when the application starts:

```elixir
config :ex_astro,
  spice_kernels: [
    "priv/kernels/lsk/naif0012.tls",
    "priv/kernels/pck/pck00011.tpc",
    "priv/kernels/spk/planets/de440.bsp"
  ]
```

Kernels downloaded after startup can be managed at runtime:

```elixir
:ok = Astro.Kernel.load("/path/to/kernel.bsp")
Astro.Kernel.loaded()
:ok = Astro.Kernel.unload("/path/to/kernel.bsp")
```

Missing configured files log a warning instead of preventing application
startup, so they can be downloaded and loaded later. Kernel mutations update
the library's independent NIF pools sequentially, not atomically; perform them
during startup or another period when no Astro calls are running.

## Time API

`Astro.Time` represents Julian Dates as two-part tuples `{jd1, jd2}` rather
than a single float. This follows ERFA/SOFA conventions and preserves much more
precision for time-scale conversions.

```elixir
iex> jd = Astro.Time.to_julian_date(~N[2000-01-01 12:00:00])
iex> jd
{2451544.5, 0.5}
iex> Astro.Time.day2sec(jd)
0.0
```

## Ephemeris and Orbit APIs

`Astro.Ephemeris` provides the low-level SPICE state and conic operations.
`Astro.Orbit` adds named osculating elements, propagation, derived quantities,
anomaly calculations, and perifocal geometry:

```elixir
# UTC timestamp -> SPICE ephemeris time
et = Astro.Time.to_et(~U[2026-08-14 00:00:00Z])

# osculating orbit of Earth around the Sun in the ecliptic frame
{:ok, orbit} =
  Astro.Orbit.osculating("3", "10", et, frame: "ECLIPJ2000")

semi_major_axis_km = Astro.Orbit.semi_major_axis(orbit)
period_seconds = Astro.Orbit.period(orbit)
```

`Astro.Support` handles the metadata around these calls: body name/ID
translation (`bodn2c/1`, `bodc2n/1`), scalar gravitational parameters
(`gm/1`), general kernel-pool constants (`bodvcd/2`, `bodvrd/2`), and SPK file
inspection (`spkobj/1`).

## Star Catalog API

`Astro.Star` propagates caller-supplied Gaia, Hipparcos, and other star-catalog
entries between two-part TDB Julian Date epochs. It also converts catalog
coordinates to and from six-element BCRS position/velocity vectors. Catalog
data is not bundled with the library.

```elixir
iex> Astro.Star.starpv(ra, dec, pm_ra, pm_dec, parallax, radial_velocity)
{:ok, [x, y, z, vx, vy, vz]}
```

## Examples

The [`examples/`](https://github.com/sgiath/ex_astro/tree/master/examples)
directory contains runnable, self-contained scripts:

- [`orbits.exs`](https://github.com/sgiath/ex_astro/blob/master/examples/orbits.exs) —
  draws the SVG orbit diagrams above from JPL ephemerides; the
  [walkthrough](examples/README.md) maps each step to the library call that
  does the work
