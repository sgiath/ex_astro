# Examples

## Drawing the Solar System

[`orbits.exs`](https://github.com/sgiath/ex_astro/blob/master/examples/orbits.exs)
is a self-contained script that turns JPL ephemerides into SVG orbit diagrams using `ex_astro`.
Everything astronomical in it - the time-scale conversions, the body states, the orbital
elements - is a library call; the rest is plain Elixir and a bit of SVG.

<p align="center">
  <img src="https://raw.githubusercontent.com/sgiath/ex_astro/master/examples/inner-system.svg" width="49%" alt="Inner solar system with the main asteroid belt, true scale"/>
  <img src="https://raw.githubusercontent.com/sgiath/ex_astro/master/examples/solar-system.svg" width="49%" alt="The nine planets, radially compressed"/>
</p>

These are not artist's impressions: every ellipse is the real osculating orbit
of the body at the epoch, computed from the same DE440 ephemeris data that JPL
uses. Eccentricities, inclinations, and node/periapsis orientations are true;
the dots sit at the true positions and revolve with true period ratios.

### Running It

```bash
elixir orbits.exs
```

The script downloads about 92 MB of SPICE kernels to `~/.cache/ex_astro/kernels`
on first run (sha256-verified), then writes `solar-system.svg` and
`inner-system.svg` next to itself. The NIF build needs a C toolchain, liberfa
and libgmp at link time - inside this repo's flake: `nix develop -c elixir orbits.exs`.

### How the Library Is Used

#### 1. Load kernels at runtime

SPICE reads everything - positions, masses, reference frames - from kernel
files. Install the library first, download the files with `Req`, then load each
path:

```elixir
Mix.install([{:ex_astro, "~> 0.3"}])

kernel_paths = [
  "~/.cache/ex_astro/kernels/de440s.bsp",
  "~/.cache/ex_astro/kernels/gm_de440.tpc",
  "~/.cache/ex_astro/kernels/codes_300ast_20100725.tf"
]

Enum.each(kernel_paths, &(:ok = Astro.Kernel.load(&1)))
```

`orbits.exs` streams missing files to disk with `Req`, verifies their sha256
digests, and loads them after `Mix.install/2`. In a regular Mix project,
`mix astro.kernels` downloads a useful default set into `priv/kernels/`; list
the paths under `config :ex_astro, :spice_kernels, [...]` to load them when the
application starts.

#### 2. Convert the epoch to ephemeris time

SPICE functions take _ephemeris time_: TDB seconds past J2000.
`Astro.Time.to_et/1` performs the UTC -> TAI -> TT -> TDB chain:

```elixir
et = Astro.Time.to_et(~U[2026-08-14 00:00:00Z])
```

Internally, the conversion uses ERFA/SOFA two-part Julian Dates to preserve
sub-microsecond precision instead of collapsing the epoch to a single float.

#### 3. Ask for a state vector

`Astro.Ephemeris.spkezr/5` returns the position and velocity of one body
relative to another, in any SPICE reference frame. Bodies are named by NAIF ID
strings (`"10"` = Sun, `"3"` = Earth-Moon barycenter, `"2000001"` = Ceres) or
by name (`"EARTH"` works too - see `Astro.Support.bodn2c/1`):

```elixir
# state of Earth relative to the Sun, ecliptic frame, no aberration correction
{:ok, [x, y, z, vx, vy, vz] = state, _light_time} =
  Astro.Ephemeris.spkezr("3", et, "ECLIPJ2000", "NONE", "10")
# units: km and km/s
```

#### 4. Derive and use the osculating orbit

`Astro.Orbit.osculating/4` combines the geometric state with the observer's
gravitational parameter from the loaded PCK. It returns named elements instead
of SPICE's positional eight-value list:

```elixir
{:ok, orbit} =
  Astro.Orbit.osculating("3", "10", et, frame: "ECLIPJ2000")

a = Astro.Orbit.semi_major_axis(orbit)       # semi-major axis [km]
period = Astro.Orbit.period(orbit)           # orbital period [s]
{u, v, _normal} = Astro.Orbit.perifocal_basis(orbit)
eccentric_anomaly = Astro.Orbit.eccentric_anomaly_at(orbit, et)
```

The elements describe the ideal two-body orbit the target would follow if all
other perturbations switched off at that instant. `Astro.Orbit` owns the
derived conic and Kepler calculations; the remaining example code projects
each ellipse orthographically and emits it as a unit circle under a single SVG
`matrix()` transform.

### Going Further

The same pattern scales to any body pair the loaded kernels cover:

- **Moon systems** - load `jup365.bsp` or `sat441.bsp` and center scenes on
  `"599"` (Jupiter) or `"699"` (Saturn) to draw the Galilean or Saturnian
  moons. Both kernels are in the `mix astro.kernels` default set.
- **Spacecraft-style geometry** - pass `"LT+S"` instead of `"NONE"` to get
  apparent (light-time and stellar-aberration corrected) states as seen by
  the observer.
- **Positions over time** - call `spkezr/5` in a loop over `et` values to
  trace trajectories instead of osculating snapshots.


## Mapping Nearby Stars

[`stars.exs`](https://github.com/sgiath/ex_astro/blob/master/examples/stars.exs)
generates a rotating three-dimensional map of Sol and the 100 nearest
catalogued stellar systems.

<p align="center">
  <img src="https://raw.githubusercontent.com/sgiath/ex_astro/master/examples/nearby-stars.svg" width="72%" alt="Rotating 3D map of the 100 nearest stellar systems, centered on Sol"/>
</p>

Run it the same way as the orbit example:

```bash
elixir stars.exs
```

On first run it downloads the 25 August 2023 update of table A1 from
[Reylé et al. 2021](https://cdsarc.cds.unistra.fr/ftp/cats/J/A+A/650/A201/ReadMe),
_The 10 parsec sample in the Gaia era_, to
`~/.cache/ex_astro/catalogs/`. The script verifies the catalog's SHA-256 digest
and writes `nearby-stars.svg` next to itself.

Planets are removed and multiple stars are collapsed to one representative per
catalogued system. The representative with the brightest available V or Gaia
magnitude supplies the dot brightness. The 100 systems nearest after propagation
to the scene epoch fill a sphere about 20.4 light-years in radius.

The astronomical conversion is performed entirely through `Astro.Star`:

```elixir
# Propagate catalog coordinates and motion from their source epoch.
{:ok, {ra, dec, pm_ra, pm_dec, parallax, radial_velocity}} =
  Astro.Star.pmsafe(ra, dec, pm_ra, pm_dec, parallax, radial_velocity, source_epoch, scene_epoch)

# Convert the propagated entry to a BCRS Cartesian state in au and au/day.
{:ok, [x, y, z, vx, vy, vz]} =
  Astro.Star.starpv(ra, dec, pm_ra, pm_dec, parallax, radial_velocity)
```

The remaining code rotates each BCRS position into the J2000 ecliptic frame.
Instead of flattening the data once, it retains cylindrical coordinates: every
star moves around the ecliptic pole at its true radius and height. An
orthographic camera turns that motion into an ellipse in the SVG, making the
relative depth visible as the whole scene revolves. Hovering a dot shows the
system name and distance.
