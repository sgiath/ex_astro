# Real solar-system scenes, drawn from JPL ephemerides through ex_astro.
#
# Usage:
#   elixir orbits.exs
#
# Outputs (overwritten in place, next to this script):
#   * solar-system.svg  the nine planets, sun-centered (radially compressed so
#                       Mercury stays visible next to Pluto)
#   * inner-system.svg  inner planets + the five largest main-belt asteroids,
#                       true scale
#
# Data sources (downloaded to ~/.cache/ex_astro/kernels on first run,
# sha256-verified, all from https://naif.jpl.nasa.gov/pub/naif/generic_kernels/):
#   * spk/planets/de440s.bsp                   32 MB  planet barycenters, DE440
#   * pck/gm_de440.tpc                         <1 MB  DE440 gravitational parameters
#   * spk/asteroids/codes_300ast_20100725.bsp  59 MB  300 large main-belt asteroids
#   * spk/asteroids/codes_300ast_20100725.tf   <1 MB  frame kernel REQUIRED by the
#                                                     asteroid BSP (ECLIPJ2000_DE405)
#
# Method: the state vector of each body relative to the Sun at the epoch in the
# ECLIPJ2000 frame (Astro.Ephemeris.spkezr) is converted to osculating conic
# elements (Astro.Ephemeris.oscelt). Each orbit ellipse is orthographically
# projected and emitted as a unit circle under a single SVG matrix() transform —
# exact, since an ellipse under a linear map is still an ellipse. Body dots sit
# at their true eccentric anomalies at the epoch and revolve with true period
# ratios (SMIL animation, works inside <img> and GitHub's image proxy).
#
# Prerequisites: the ex_astro NIF build needs a C toolchain, liberfa and libgmp
# discoverable at link time. Inside this repo's flake: nix develop -c elixir orbits.exs

# Kernels are downloaded after Mix.install and loaded at runtime through
# Astro.Kernel, so missing files never depend on NIF module-load timing.
Mix.install(
  # outside this repository use: {:ex_astro, "~> 0.3"}
  [{:ex_astro, path: Path.expand("..", __DIR__)}]
)

defmodule Orbits.Kernels do
  @moduledoc false

  @cache Path.expand("~/.cache/ex_astro/kernels")
  @naif "https://naif.jpl.nasa.gov/pub/naif/generic_kernels"
  @kernels [
    %{
      file: "de440s.bsp",
      url: "#{@naif}/spk/planets/de440s.bsp",
      sha256: "c1c7feeab882263fc493a9d5a5b2ddd71b54826cdf65d8d17a76126b260a49f2"
    },
    %{
      file: "gm_de440.tpc",
      url: "#{@naif}/pck/gm_de440.tpc",
      sha256: "924ddf4fb9ead9fe8a1aa55780bcabde40b09d00065d58226e24b68d8092f140"
    },
    %{
      file: "codes_300ast_20100725.tf",
      url: "#{@naif}/spk/asteroids/codes_300ast_20100725.tf",
      sha256: "15ee3b1731817774672725ccc226b249eb9ca5aa5d0a6a7805c91e5f57497f40"
    },
    %{
      file: "codes_300ast_20100725.bsp",
      url: "#{@naif}/spk/asteroids/codes_300ast_20100725.bsp",
      sha256: "7bb92faaadac29ec0b62aa96041a37c92ae24b9a5460de03d3fcaa2f63fe51f0"
    }
  ]

  def paths, do: Enum.map(@kernels, &Path.join(@cache, &1.file))

  def ensure_all do
    case Enum.reject(@kernels, &File.exists?(Path.join(@cache, &1.file))) do
      [] ->
        :ok

      missing ->
        File.mkdir_p!(@cache)
        Enum.each(missing, &download/1)
    end
  end

  # Stream to .tmp, verify status + sha256, then atomically rename.
  defp download(%{file: file, url: url, sha256: expected}) do
    path = Path.join(@cache, file)
    tmp = path <> ".tmp"
    IO.puts("downloading #{file} ...")

    try do
      response =
        Req.get!(url,
          into: File.stream!(tmp),
          raw: true,
          receive_timeout: 1_800_000,
          retry: false
        )

      response.status == 200 || raise "GET #{url} -> HTTP #{response.status}"
      verify!(tmp, file, expected)
      File.rename!(tmp, path)
    after
      File.rm(tmp)
    end
  end

  defp verify!(tmp, file, expected) do
    actual =
      tmp
      |> File.stream!(1_048_576)
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    actual == expected || raise "sha256 mismatch for #{file}: expected #{expected}, got #{actual}"
  end
end

Orbits.Kernels.ensure_all()
Enum.each(Orbits.Kernels.paths(), &(:ok = Astro.Kernel.load(&1)))

defmodule Orbits do
  @moduledoc false

  @out __DIR__

  # The scenes are drawn "as of" this UTC instant. SPICE wants ephemeris time
  # (TDB seconds past J2000), so the epoch walks the whole time-scale chain:
  # UTC -> TAI -> TT -> TDB, then split Julian Date -> seconds past J2000.
  @epoch ~U[2026-08-14 00:00:00Z]

  # name => {ring opacity, dot stroke width, dot opacity, trail degrees}
  @style %{
    mercury: {0.50, 3.0, 0.90, 50},
    venus: {0.45, 4.5, 0.90, 45},
    earth: {0.45, 4.5, 0.90, 45},
    mars: {0.40, 3.5, 0.85, 45},
    jupiter: {0.32, 7.0, 0.80, 35},
    saturn: {0.28, 6.5, 0.75, 35},
    uranus: {0.24, 5.0, 0.70, 30},
    neptune: {0.22, 5.0, 0.65, 30},
    pluto: {0.30, 2.5, 0.75, 30},
    ceres: {0.26, 2.5, 0.70, 25},
    pallas: {0.22, 2.0, 0.60, 25},
    juno: {0.20, 2.0, 0.55, 25},
    vesta: {0.24, 2.2, 0.65, 25},
    hygiea: {0.20, 2.0, 0.55, 25}
  }

  # NAIF ID strings: planets by barycenter ID, asteroids by 2000000 + IAU number
  @inner [{"1", :mercury}, {"2", :venus}, {"3", :earth}, {"4", :mars}]
  @outer [{"5", :jupiter}, {"6", :saturn}, {"7", :uranus}, {"8", :neptune}, {"9", :pluto}]
  @belt [
    {"2000001", :ceres},
    {"2000002", :pallas},
    {"2000003", :juno},
    {"2000004", :vesta},
    {"2000010", :hygiea}
  ]

  # compress: 1.0 = true scale (r ~ a); the nine-planet scene compresses radial
  # distances (r ~ a^0.4) so Mercury stays visible next to Pluto. Eccentricities,
  # inclinations and orientations stay true either way.
  @scenes [
    %{
      file: "solar-system.svg",
      title: "THE NINE PLANETS",
      compress: 0.4,
      bodies: @inner ++ @outer
    },
    %{
      file: "inner-system.svg",
      title: "INNER SYSTEM \u00b7 MAIN BELT",
      compress: 1.0,
      bodies: @inner ++ @belt
    }
  ]

  @au_km 149_597_870.7
  # orthographic camera: scene rotated 15 deg, tilted 66 deg from face-on
  @tilt 66.0 * :math.pi() / 180.0
  @psi 15.0 * :math.pi() / 180.0
  @fit_extent 330.0
  @mercury_anim_s 12.0
  @trail_step_deg 5
  @font "ui-monospace, 'JetBrains Mono', 'Fira Code', monospace"

  def run do
    Enum.each(@scenes, fn scene ->
      orbits = compute(scene)
      write_scene(scene, orbits)
      print_summary(scene, orbits)
    end)
  end

  # --- the ex_astro part: epoch, states, orbital elements ---------------------

  # SPICE ephemeris time (TDB seconds past J2000) from the UTC epoch
  defp epoch_et do
    @epoch
    |> Astro.Time.to_julian_date()
    |> Astro.Time.utc2tai()
    |> Astro.Time.tai2tt()
    |> Astro.Time.tt2tdb()
    |> Astro.Time.day2sec()
  end

  defp compute(%{compress: compress, bodies: bodies}) do
    # gravitational parameter of the Sun (NAIF ID 10) from gm_de440.tpc
    {:ok, [mu]} = Astro.Support.bodvcd(10, "GM")
    orbits = Enum.map(bodies, &orbit(&1, mu, compress))
    scale = @fit_extent / max_extent(orbits)
    Enum.map(orbits, &rescale(&1, scale))
  end

  defp orbit({id, name}, mu, compress) do
    # geometric state of the body relative to the Sun ("10") in the ecliptic
    # frame [km, km/s], then osculating conic elements at the same epoch
    {:ok, state, _lt} = Astro.Ephemeris.spkezr(id, epoch_et(), "ECLIPJ2000", "NONE", "10")
    {:ok, [rp, e, inc, node, argp, m0, _t0, _mu]} = Astro.Ephemeris.oscelt(state, epoch_et(), mu)

    a_km = rp / (1.0 - e)
    period_s = 2.0 * :math.pi() * :math.sqrt(a_km * a_km * a_km / mu)

    # in-plane basis in ecliptic coordinates: u toward periapsis, v advanced 90 deg
    {cw, sw} = {:math.cos(argp), :math.sin(argp)}
    {co, so} = {:math.cos(node), :math.sin(node)}
    {ci, si} = {:math.cos(inc), :math.sin(inc)}
    u = {cw * co - sw * so * ci, cw * so + sw * co * ci, sw * si}
    v = {-sw * co - cw * so * ci, -sw * so + cw * co * ci, cw * si}

    # radial compression: uniform per-orbit scale keeps e, i and orientations true
    semi_major = :math.pow(a_km / @au_km, compress)
    semi_minor = semi_major * :math.sqrt(1.0 - e * e)
    {ring_op, dot_w, dot_op, trail_deg} = Map.fetch!(@style, name)

    %{
      name: name,
      ring_op: ring_op,
      dot_w: dot_w,
      dot_op: dot_op,
      trail_deg: trail_deg,
      a_au: a_km / @au_km,
      e: e,
      inc: inc,
      period_s: period_s,
      ecc_anomaly: kepler(normalize(m0), e),
      p: scale2(project(u), semi_major),
      q: scale2(project(v), semi_minor),
      c: scale2(project(u), -semi_major * e)
    }
  end

  # --- geometry ----------------------------------------------------------------

  defp normalize(m) when m > 3.141592653589793, do: m - 2.0 * :math.pi()
  defp normalize(m), do: m

  # Kepler's equation M = E - e sin E, solved by Newton iteration
  defp kepler(m, e), do: kepler_iter(m + e * :math.sin(m), m, e, 0)

  defp kepler_iter(ec, _m, _e, 60), do: ec

  defp kepler_iter(ec, m, e, n) do
    delta = (m - (ec - e * :math.sin(ec))) / (1.0 - e * :math.cos(ec))
    if abs(delta) < 1.0e-13, do: ec + delta, else: kepler_iter(ec + delta, m, e, n + 1)
  end

  # scene rotation about ecliptic pole, camera tilt from face-on, y flipped for SVG
  defp project({x, y, z}) do
    x1 = x * :math.cos(@psi) - y * :math.sin(@psi)
    y1 = x * :math.sin(@psi) + y * :math.cos(@psi)
    {x1, -(y1 * :math.cos(@tilt) - z * :math.sin(@tilt))}
  end

  defp scale2({x, y}, s), do: {x * s, y * s}

  defp max_extent(orbits) do
    for %{p: {px, py}, q: {qx, qy}, c: {cx, cy}} <- orbits,
        t <- 0..719,
        reduce: 0.0 do
      acc ->
        th = t * :math.pi() / 360.0
        x = cx + px * :math.cos(th) + qx * :math.sin(th)
        y = cy + py * :math.cos(th) + qy * :math.sin(th)
        max(acc, max(abs(x), abs(y)))
    end
  end

  defp rescale(orbit, s) do
    %{orbit | p: scale2(orbit.p, s), q: scale2(orbit.q, s), c: scale2(orbit.c, s)}
  end

  # --- SVG emission --------------------------------------------------------------

  defp f(value, decimals) do
    value
    |> :erlang.float_to_binary(decimals: decimals)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
    |> case do
      "-0" -> "0"
      s -> s
    end
  end

  defp matrix(%{p: {px, py}, q: {qx, qy}, c: {cx, cy}}) do
    values = Enum.map_join([px, py, qx, qy, cx, cy], " ", &f(&1, 2))
    "matrix(#{values})"
  end

  defp ring(%{ring_op: op}) do
    ~s(<circle r="1" stroke-opacity="#{f(op, 2)}" vector-effect="non-scaling-stroke"/>)
  end

  defp dot(%{ecc_anomaly: ea, dot_w: w, dot_op: op}) do
    ~s(<path d="M #{f(:math.cos(ea), 4)} #{f(:math.sin(ea), 4)} l .0001 0" ) <>
      ~s(stroke-width="#{f(w, 1)}" stroke-linecap="round" stroke-opacity="#{f(op, 2)}" ) <>
      ~s(vector-effect="non-scaling-stroke"/>)
  end

  defp trail(%{ecc_anomaly: ea, trail_deg: deg, ring_op: op}) do
    points =
      deg..0//-@trail_step_deg
      |> Enum.map(fn d -> ea - d * :math.pi() / 180.0 end)
      |> Enum.map_join(" L ", fn th -> "#{f(:math.cos(th), 4)} #{f(:math.sin(th), 4)}" end)

    ~s(<path d="M #{points}" stroke-opacity="#{f(op + 0.05, 2)}" stroke-linecap="round" ) <>
      ~s(vector-effect="non-scaling-stroke"/>)
  end

  # animation periods normalized so Mercury takes @mercury_anim_s per orbit
  defp anim_period(orbits, %{period_s: t}) do
    %{period_s: t_mercury} = Enum.find(orbits, &(&1.name == :mercury))
    f(@mercury_anim_s * t / t_mercury, 1)
  end

  defp write_scene(%{file: file, title: title, compress: k}, orbits) do
    parts =
      Enum.map_join(orbits, "\n", fn o ->
        """
            <!-- #{o.name}: T = #{f(o.period_s / 86_400 / 365.25, 2)} y -->
            <g transform="#{matrix(o)}">
              #{ring(o)}
              <g>
                <animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="#{anim_period(orbits, o)}s" repeatCount="indefinite"/>
                #{trail(o)}
                #{dot(o)}
              </g>
            </g>\
        """
      end)

    svg = """
    <svg xmlns="http://www.w3.org/2000/svg" width="800" height="800" viewBox="0 0 800 800" role="img" aria-label="#{title}">
      <desc>
        #{title} at #{@epoch} — real osculating orbits from JPL ephemerides
        (DE440s planets, gm_de440 GM constants, CODES codes_300ast asteroids;
        https://naif.jpl.nasa.gov/pub/naif/generic_kernels/) through the
        ex_astro library (SPICE spkezr + oscelt, sun-centered, ECLIPJ2000
        frame). Each orbit is the osculating conic at the epoch,
        orthographically projected (scene rotated 15 deg, camera tilted 66 deg
        from face-on) and drawn as a unit circle under a matrix() transform.
        Eccentricities, inclinations and node/periapsis orientations are true;
        #{scale_note(k)} Body dots start at their true eccentric anomalies and
        revolve with true period ratios.
        Generated by examples/orbits.exs — do not edit by hand.
      </desc>
      <rect x="0.5" y="0.5" width="799" height="799" rx="12" fill="#050505" stroke="#1c1c1f"/>
      <g transform="translate(400 400)" fill="none" stroke="#e6e6e9" stroke-width="1">
    #{parts}
        <!-- sun -->
        <circle r="4" fill="#e25d52" stroke="none" opacity="0.9"/>
      </g>
      <g font-family="#{@font}" font-size="11" letter-spacing="2.5" fill="#606069">
        <text x="28" y="36" fill="#9d9da6" font-size="12">EX_ASTRO</text>
        <text x="772" y="36" text-anchor="end">#{Calendar.strftime(@epoch, "%Y-%m-%d")} UTC</text>
        <text x="28" y="774">#{title}</text>
        <text x="772" y="774" text-anchor="end">DE440 \u00b7 SPICE SPKEZR/OSCELT</text>
      </g>
    </svg>
    """

    path = Path.join(@out, file)
    File.write!(path, svg)
    IO.puts("wrote #{path}")
  end

  defp scale_note(1.0), do: "radial distances are to scale (r ~ a)."
  defp scale_note(k), do: "radial distances are compressed (r ~ a^#{k})."

  defp print_summary(%{file: file}, orbits) do
    IO.puts("\n  #{file}")
    IO.puts("  body        a [au]      e       i [deg]  E0 [deg]  T")

    Enum.each(orbits, fn o ->
      deg = 180.0 / :math.pi()

      IO.puts(
        String.pad_trailing("  #{o.name}", 14) <>
          String.pad_trailing(f(o.a_au, 4), 12) <>
          String.pad_trailing(f(o.e, 4), 8) <>
          String.pad_trailing(f(o.inc * deg, 2), 9) <>
          String.pad_trailing(f(o.ecc_anomaly * deg, 1), 10) <>
          "#{f(o.period_s / 86_400, 1)}d"
      )
    end)

    IO.puts("")
  end
end

Orbits.run()
