# Example: Drawing the Solar System

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

## Running It

```bash
elixir orbits.exs
```

The script downloads about 92 MB of SPICE kernels to `~/.cache/ex_astro/kernels`
on first run (sha256-verified), then writes `solar-system.svg` and
`inner-system.svg` next to itself. The NIF build needs a C toolchain, liberfa
and libgmp at link time - inside this repo's flake: `nix develop -c elixir orbits.exs`.

## How the Library Is Used

### 1. Load kernels at runtime

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

### 2. Convert the epoch to ephemeris time

SPICE functions take _ephemeris time_: TDB seconds past J2000. Starting from
an ordinary UTC timestamp, `Astro.Time` walks the whole time-scale chain:

```elixir
et =
  ~U[2026-08-14 00:00:00Z]
  |> Astro.Time.to_julian_date()  # UTC as a split Julian Date {jd1, jd2}
  |> Astro.Time.utc2tai()         # + accumulated leap seconds
  |> Astro.Time.tai2tt()          # + 32.184 s
  |> Astro.Time.tt2tdb()          # periodic relativistic terms, < 2 ms
  |> Astro.Time.day2sec()         # split JD -> seconds past J2000
```

The split `{jd1, jd2}` representation follows ERFA/SOFA conventions and keeps
sub-microsecond precision through the conversions - a single float Julian Date
cannot.

### 3. Ask for a state vector

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

### 4. Convert the state to orbital elements

`Astro.Ephemeris.oscelt/3` turns a state vector into the osculating conic -
the ideal two-body orbit the body would follow if all other perturbations
switched off at that instant. It needs the gravitational parameter of the
central body, which `Astro.Support.bodvcd/2` reads from the loaded
`gm_de440.tpc` kernel:

```elixir
{:ok, [mu]} = Astro.Support.bodvcd(10, "GM")

{:ok, [rp, ecc, inc, node, argp, m0, _t0, _mu]} =
  Astro.Ephemeris.oscelt(state, et, mu)

a = rp / (1.0 - ecc)                                # semi-major axis [km]
period = 2 * :math.pi() * :math.sqrt(a ** 3 / mu)   # orbital period [s]
```

That is the entire astronomical core of the script. The remaining code solves
Kepler's equation for the dot positions, projects each ellipse
orthographically, and emits it as a unit circle under a single SVG `matrix()`
transform - exact, because an ellipse under a linear map is still an ellipse.

## Going Further

The same pattern scales to any body pair the loaded kernels cover:

- **Moon systems** - load `jup365.bsp` or `sat441.bsp` and center scenes on
  `"599"` (Jupiter) or `"699"` (Saturn) to draw the Galilean or Saturnian
  moons. Both kernels are in the `mix astro.kernels` default set.
- **Spacecraft-style geometry** - pass `"LT+S"` instead of `"NONE"` to get
  apparent (light-time and stellar-aberration corrected) states as seen by
  the observer.
- **Positions over time** - call `spkezr/5` in a loop over `et` values to
  trace trajectories instead of osculating snapshots.
