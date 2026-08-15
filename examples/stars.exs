# Nearby stellar systems, propagated with ERFA through ex_astro and drawn as a
# rotating three-dimensional SVG map.
#
# Usage:
#   elixir stars.exs
#
# Output (overwritten in place, next to this script):
#   * nearby-stars.svg  Sol and the 100 nearest catalogued stellar systems
#
# Data source (downloaded to ~/.cache/ex_astro/catalogs on first run and
# sha256-verified):
#   * VizieR J/A+A/650/A201/tablea1.dat, update 25-Aug-2023
#     "The 10 parsec sample in the Gaia era" (Reyle et al. 2021)
#
# Method: one representative (the brightest catalogued member) is retained per
# system. Astro.Star.pmsafe/8 propagates its catalog astrometry to the scene
# epoch, then Astro.Star.starpv/6 turns it into a BCRS Cartesian vector. The 100
# nearest systems are rotated into the J2000 ecliptic frame, orthographically
# projected, and animated about the ecliptic pole with SVG SMIL transforms.
#
# Prerequisites: the ex_astro NIF build needs a C toolchain and liberfa
# discoverable at link time. Inside this repo's flake:
#   nix develop -c elixir stars.exs

Mix.install(
  # outside this repository use: {:ex_astro, "~> 0.3"}
  [{:ex_astro, path: Path.expand("..", __DIR__)}]
)

defmodule NearbyStars.Catalog do
  @moduledoc false

  @cache Path.expand("~/.cache/ex_astro/catalogs/tablea1.dat")
  @url "https://cdsarc.cds.unistra.fr/ftp/cats/J/A+A/650/A201/tablea1.dat.gz"
  @sha256 "dcd8ed6d4d338ef1cafff867bbb3c85e0737d9082509311d80fd1cdfdf79e7f8"

  def read! do
    case File.read(@cache) do
      {:ok, catalog} ->
        verify!(catalog)
        catalog

      {:error, :enoent} ->
        download!()

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read file", path: @cache
    end
  end

  defp download! do
    IO.puts("downloading VizieR 10 pc catalog ...")
    response = Req.get!(@url, raw: true, receive_timeout: 120_000, retry: false)
    response.status == 200 || raise "GET #{@url} -> HTTP #{response.status}"

    catalog = :zlib.gunzip(response.body)
    verify!(catalog)
    File.mkdir_p!(Path.dirname(@cache))
    File.write!(@cache <> ".tmp", catalog)
    File.rename!(@cache <> ".tmp", @cache)
    catalog
  end

  defp verify!(catalog) do
    actual =
      catalog
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)

    actual == @sha256 ||
      raise "catalog sha256 mismatch: expected #{@sha256}, got #{actual}"

    :ok
  end
end

defmodule NearbyStars do
  @moduledoc false

  @out Path.join(__DIR__, "nearby-stars.svg")
  @epoch ~U[2026-08-14 00:00:00Z]
  @star_count 100
  @au_per_ly 63_241.077
  @deg :math.pi() / 180.0
  @mas_to_rad :math.pi() / (180.0 * 3_600.0 * 1_000.0)
  # IAU 1976 mean obliquity of J2000: ICRS to ecliptic, about +x.
  @obliquity 23.4392911 * @deg
  # Match the orbit examples: scene rotated 15 degrees and camera tilted 66
  # degrees from face-on.
  @scene_rotation 15.0 * @deg
  @camera_tilt 66.0 * @deg
  @center 400.0
  @fit_radius 310.0
  @rotation_s 90
  @font "ui-monospace, 'JetBrains Mono', 'Fira Code', monospace"

  def run do
    stars =
      NearbyStars.Catalog.read!()
      |> parse_systems()
      |> Enum.map(&place/1)
      |> Enum.sort_by(& &1.distance)
      |> Enum.take(@star_count)

    scale = @fit_radius / List.last(stars).distance
    File.write!(@out, svg(stars, scale))
    print_summary(stars)
    IO.puts("wrote #{@out}")
  end

  defp parse_systems(catalog) do
    catalog
    |> String.split("\n", trim: true)
    |> Enum.map(&parse_row/1)
    |> Enum.reject(&(&1.object_type == "Planet"))
    |> Enum.group_by(& &1.system)
    |> Enum.map(fn {_system, members} -> Enum.min_by(members, & &1.magnitude) end)
  end

  defp parse_row(line) do
    visual = parse_float(field(line, 406, 412))
    gaia = parse_float(field(line, 353, 361))
    gaia_estimate = parse_float(field(line, 363, 368))
    common_name = field(line, 545, 561)
    catalog_name = field(line, 11, 39)

    %{
      system: parse_integer!(field(line, 6, 9)),
      object_type: field(line, 41, 46),
      ra: parse_float!(field(line, 79, 91)),
      dec: parse_float!(field(line, 94, 106)),
      epoch: parse_float!(field(line, 108, 113)),
      parallax: parse_float!(field(line, 115, 122)),
      pm_ra: parse_float(field(line, 165, 180)) || 0.0,
      pm_dec: parse_float(field(line, 199, 214)) || 0.0,
      radial_velocity: parse_float(field(line, 264, 271)) || 0.0,
      magnitude: visual || gaia || gaia_estimate || 20.0,
      name: if(common_name == "", do: catalog_name, else: common_name)
    }
  end

  defp field(line, first, last) do
    line
    |> binary_part(first - 1, last - first + 1)
    |> String.trim()
  end

  defp parse_float(""), do: nil

  defp parse_float(value) do
    case Float.parse(value) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp parse_float!(value), do: parse_float(value) || raise("invalid float: #{inspect(value)}")

  defp parse_integer!(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _ -> raise "invalid integer: #{inspect(value)}"
    end
  end

  # --- the ex_astro part: catalog propagation and BCRS vectors ---------------

  defp place(star) do
    ra = star.ra * @deg
    dec = star.dec * @deg
    # The catalog's pmRA already includes cos(dec); ERFA expects dRA/dt.
    pm_ra = star.pm_ra / :math.cos(dec) * @mas_to_rad
    pm_dec = star.pm_dec * @mas_to_rad
    parallax = star.parallax / 1_000.0
    source_epoch = {2_451_545.0, (star.epoch - 2000.0) * 365.25}
    scene_epoch = {2_451_545.0, Astro.Time.to_et(@epoch) / 86_400.0}

    {ra2, dec2, pm_ra2, pm_dec2, parallax2, radial_velocity2} =
      star
      |> propagate(ra, dec, pm_ra, pm_dec, parallax, source_epoch, scene_epoch)

    [x, y, z | _velocity] =
      unwrap(
        Astro.Star.starpv(
          ra2,
          dec2,
          pm_ra2,
          pm_dec2,
          parallax2,
          radial_velocity2
        ),
        :starpv,
        star.name
      )

    {ex, ey, ez} = to_ecliptic({x / @au_per_ly, y / @au_per_ly, z / @au_per_ly})

    Map.merge(star, %{
      distance: :math.sqrt(ex * ex + ey * ey + ez * ez),
      radius_xy: :math.sqrt(ex * ex + ey * ey),
      phase: :math.atan2(ey, ex),
      z: ez
    })
  end

  defp propagate(star, ra, dec, pm_ra, pm_dec, parallax, source_epoch, scene_epoch) do
    unwrap(
      Astro.Star.pmsafe(
        ra,
        dec,
        pm_ra,
        pm_dec,
        parallax,
        star.radial_velocity,
        source_epoch,
        scene_epoch
      ),
      :pmsafe,
      star.name
    )
  end

  defp unwrap({:ok, value}, _operation, _name), do: value

  defp unwrap({:ok, value, warnings}, operation, name) do
    IO.warn("#{operation} #{name}: #{inspect(warnings)}")
    value
  end

  defp unwrap({:error, reason}, operation, name) do
    raise "#{operation} failed for #{name}: #{inspect(reason)}"
  end

  defp to_ecliptic({x, y, z}) do
    cosine = :math.cos(@obliquity)
    sine = :math.sin(@obliquity)
    {x, y * cosine + z * sine, -y * sine + z * cosine}
  end

  # --- geometry and SVG emission ---------------------------------------------

  defp project({x, y, z}) do
    x1 = x * :math.cos(@scene_rotation) - y * :math.sin(@scene_rotation)
    y1 = x * :math.sin(@scene_rotation) + y * :math.cos(@scene_rotation)
    {x1, -(y1 * :math.cos(@camera_tilt) - z * :math.sin(@camera_tilt))}
  end

  defp svg(stars, scale) do
    dots = Enum.map_join(stars, "\n", &star_svg(&1, scale))
    shells = Enum.map_join([5, 10, 15, 20], "\n", &shell_svg(&1, scale))
    furthest = List.last(stars).distance

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="800" height="800" viewBox="0 0 800 800" role="img" aria-label="The 100 nearest stellar systems in 3D">
      <desc>
        The #{@star_count} nearest stellar systems to Sol from Reyle et al. 2021,
        A&amp;A 650 A201, VizieR J/A+A/650/A201 tablea1 update 25-Aug-2023.
        One representative (the brightest catalogued member) is retained per
        system. Astrometry is propagated to #{@epoch} with ERFA eraPmsafe and
        eraStarpv through ex_astro, rotated from ICRS to the J2000 ecliptic,
        and orthographically projected with a 66 degree camera tilt. The scene
        revolves about the ecliptic pole once every #{@rotation_s} seconds. Sol is
        centered; the outermost system is #{format(furthest, 2)} light-years away.
        Generated by examples/stars.exs; do not edit by hand.
      </desc>
      <rect x="0.5" y="0.5" width="799" height="799" rx="12" fill="#050505" stroke="#1c1c1f"/>
      <g transform="translate(#{format(@center, 0)} #{format(@center, 0)})" fill="none">
        <g stroke="#303036" stroke-width="1">
    #{shells}
        </g>
        <path d="M 0 #{format(-22 * scale, 2)} V #{format(22 * scale, 2)}" stroke="#26262b" stroke-dasharray="2 5"/>
        <g stroke="#e6e6e9">
    #{dots}
        </g>
        <circle r="4" fill="#e25d52"/>
        <text x="9" y="4" fill="#b7b7bf" font-family="#{@font}" font-size="10">SOL</text>
      </g>
      <g font-family="#{@font}" font-size="11" letter-spacing="2.5" fill="#606069">
        <text x="28" y="36" fill="#9d9da6" font-size="12">EX_ASTRO</text>
        <text x="772" y="36" text-anchor="end">#{Calendar.strftime(@epoch, "%Y-%m-%d")} UTC</text>
        <text x="28" y="774">100 NEAREST SYSTEMS · 5 LY RINGS</text>
        <text x="772" y="774" text-anchor="end">ERFA · REYLÉ+ 2021</text>
      </g>
    </svg>
    """
  end

  defp shell_svg(light_years, scale) do
    {px, py} = scaled_project({light_years, 0.0, 0.0}, scale)
    {qx, qy} = scaled_project({0.0, light_years, 0.0}, scale)
    matrix = matrix([px, py, qx, qy, 0.0, 0.0])

    ~s(<circle r="1" transform="#{matrix}" vector-effect="non-scaling-stroke"/>)
  end

  defp star_svg(star, scale) do
    {px, py} = scaled_project({star.radius_xy, 0.0, 0.0}, scale)
    {qx, qy} = scaled_project({0.0, star.radius_xy, 0.0}, scale)
    {ox, oy} = scaled_project({0.0, 0.0, star.z}, scale)
    transform = matrix([px, py, qx, qy, ox, oy])
    width = clamp(4.2 - 0.22 * star.magnitude, 1.2, 4.2)
    opacity = clamp(0.82 - 0.04 * star.magnitude, 0.22, 0.82)
    x = format(:math.cos(star.phase), 5)
    y = format(:math.sin(star.phase), 5)

    """
        <g transform="#{transform}">
          <g>
            <animateTransform attributeName="transform" type="rotate" from="0" to="360" dur="#{@rotation_s}s" repeatCount="indefinite"/>
            <path d="M #{x} #{y} l .0001 0" stroke-width="#{format(width, 2)}" stroke-linecap="round" stroke-opacity="#{format(opacity, 2)}" vector-effect="non-scaling-stroke">
              <title>#{escape(star.name)} · #{format(star.distance, 2)} ly</title>
            </path>
          </g>
        </g>\
    """
  end

  defp scaled_project(point, scale) do
    {x, y} = project(point)
    {x * scale, y * scale}
  end

  defp matrix(values), do: "matrix(#{Enum.map_join(values, " ", &format(&1, 2))})"

  defp escape(value) do
    value
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
  end

  defp clamp(value, low, high), do: value |> max(low) |> min(high)

  defp format(value, 0) do
    value
    |> :erlang.float_to_binary(decimals: 0)
    |> case do
      "-0" -> "0"
      number -> number
    end
  end

  defp format(value, decimals) do
    value
    |> :erlang.float_to_binary(decimals: decimals)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
    |> case do
      "-0" -> "0"
      number -> number
    end
  end

  defp print_summary(stars) do
    IO.puts("\n  nearby-stars.svg")
    IO.puts("  system                        distance")

    stars
    |> Enum.take(12)
    |> Enum.each(fn star ->
      IO.puts(
        String.pad_trailing("  #{star.name}", 32) <>
          "#{format(star.distance, 2)} ly"
      )
    end)

    IO.puts("  ... #{length(stars)} systems; radius #{format(List.last(stars).distance, 2)} ly\n")
  end
end

NearbyStars.run()
