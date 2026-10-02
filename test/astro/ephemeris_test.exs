defmodule Astro.EphemerisTest do
  use ExUnit.Case, async: true

  doctest Astro.Ephemeris

  # Reference values from JPL Horizons (DE441) for 2025-Nov-21 00:00:00 TDB
  # (JD 2461000.5), ICRF axes, km and km/s. The library loads DE440, which
  # agrees with DE441 to well under a kilometer for these bodies.
  @et (2_461_000.5 - 2_451_545.0) * 86_400.0

  # Horizons VECTORS, COMMAND=399, CENTER=500@10, VEC_CORR=NONE
  @earth_from_sun [
    7.708376725859748e7,
    1.157075406782461e8,
    5.015717517316379e7,
    -2.591127972866548e1,
    1.415542313920248e1,
    6.136432087380158e0
  ]
  @earth_from_sun_lt 4.930195175071745e2

  # Horizons VECTORS, COMMAND=4, CENTER=500@399, VEC_CORR=LT
  @mars_from_earth_lt [
    -1.145911228830736e8,
    -3.139674878149913e8,
    -1.400826126268110e8,
    5.070522748540368e1,
    -1.576053773294104e1,
    -7.541410215861382e0
  ]
  @mars_from_earth_lt_lt 1.208818273597812e3

  # Horizons VECTORS, COMMAND=4, CENTER=500@399, VEC_CORR=LT+S (position only;
  # Horizons does not aberrate the velocity)
  @mars_from_earth_apparent_position [-1.146248934216085e8, -3.139571261392578e8, -1.400782065964461e8]

  # Horizons ELEMENTS, COMMAND=399, CENTER=500@10, REF_PLANE=FRAME
  @horizons_keplerian_gm 1.3271283864171489e11
  @earth_elements %{
    rp: 1.471360441715657e8,
    ecc: 1.729459436739474e-2,
    inc_deg: 2.343615841937300e1,
    lnode_deg: 1.145081961082815e-3,
    argp_deg: 1.013110497390046e2,
    m0_deg: 3.185855008712534e2
  }

  test "spkezr geometric state matches JPL Horizons" do
    assert {:ok, state, light_time} = Astro.Ephemeris.spkezr("EARTH", @et, "J2000", "NONE", "SUN")

    assert_state(state, @earth_from_sun, 1.0e-3, 1.0e-9)
    assert_in_delta light_time, @earth_from_sun_lt, 1.0e-9
  end

  test "spkez and spkgeo agree with Horizons for integer body IDs" do
    assert {:ok, state, _light_time} = Astro.Ephemeris.spkez(399, @et, "J2000", "NONE", 10)
    assert_state(state, @earth_from_sun, 1.0e-3, 1.0e-9)

    assert {:ok, state, light_time} = Astro.Ephemeris.spkgeo(399, @et, "J2000", 10)
    assert_state(state, @earth_from_sun, 1.0e-3, 1.0e-9)
    assert_in_delta light_time, @earth_from_sun_lt, 1.0e-9
  end

  test "light-time and stellar-aberration corrections match Horizons" do
    assert {:ok, state, light_time} = Astro.Ephemeris.spkezr("4", @et, "J2000", "LT", "399")

    # Horizons does not scale velocity by the light-time rate, SPICE does.
    assert_state(state, @mars_from_earth_lt, 2.0, 1.0e-4)
    assert_in_delta light_time, @mars_from_earth_lt_lt, 1.0e-5

    assert {:ok, apparent, _light_time} = Astro.Ephemeris.spkezr("4", @et, "J2000", "LT+S", "399")

    assert_state(Enum.take(apparent, 3), @mars_from_earth_apparent_position, 2.0, nil)
    # Stellar aberration moves the apparent position by ~34,000 km here.
    assert abs(Enum.at(apparent, 0) - Enum.at(state, 0)) > 30_000.0
  end

  test "spkezr reports unknown bodies" do
    assert {:error, message} = Astro.Ephemeris.spkezr("NOT_A_BODY", 0.0, "J2000", "NONE", "SSB")
    assert message =~ "NOT_A_BODY"
  end

  test "oscelt matches Horizons osculating elements" do
    {:ok, state, _light_time} = Astro.Ephemeris.spkezr("EARTH", @et, "J2000", "NONE", "SUN")

    assert {:ok, [rp, ecc, inc, lnode, argp, m0, epoch, mu]} =
             Astro.Ephemeris.oscelt(state, @et, @horizons_keplerian_gm)

    assert_in_delta rp, @earth_elements.rp, 1.0e-2
    assert_in_delta ecc, @earth_elements.ecc, 1.0e-10
    assert_in_delta degrees(inc), @earth_elements.inc_deg, 1.0e-8
    assert_in_delta degrees(lnode), @earth_elements.lnode_deg, 1.0e-8
    assert_in_delta degrees(argp), @earth_elements.argp_deg, 1.0e-6
    assert_in_delta degrees(m0), @earth_elements.m0_deg, 1.0e-6
    assert epoch == @et
    assert mu == @horizons_keplerian_gm
  end

  test "conics propagates analytic circular, elliptic, and hyperbolic orbits" do
    mu = 398_600.435_436
    r = 7_000.0
    circular_period = 2.0 * :math.pi() * :math.sqrt(r ** 3 / mu)
    circular_speed = :math.sqrt(mu / r)

    # A quarter revolution moves a circular equatorial orbit from +x to +y.
    assert {:ok, state} = Astro.Ephemeris.conics([r, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, mu], circular_period / 4.0)
    assert_state(state, [0.0, r, 0.0, -circular_speed, 0.0, 0.0], 1.0e-6, 1.0e-9)

    # Half a revolution after periapsis an ellipse is at apoapsis.
    ecc = 0.3
    a = r / (1.0 - ecc)
    ra = a * (1.0 + ecc)
    elliptic_period = 2.0 * :math.pi() * :math.sqrt(a ** 3 / mu)
    apoapsis_speed = :math.sqrt(mu * (2.0 / ra - 1.0 / a))

    assert {:ok, state} = Astro.Ephemeris.conics([r, ecc, 0.0, 0.0, 0.0, 0.0, 0.0, mu], elliptic_period / 2.0)
    assert_state(state, [-ra, 0.0, 0.0, 0.0, -apoapsis_speed, 0.0], 1.0e-6, 1.0e-9)

    # A hyperbola at periapsis moves perpendicular to the radius vector.
    ecc = 1.5
    periapsis_speed = :math.sqrt(mu * (1.0 + ecc) / r)

    assert {:ok, state} = Astro.Ephemeris.conics([r, ecc, 0.0, 0.0, 0.0, 0.0, 100.0, mu], 100.0)
    assert_state(state, [r, 0.0, 0.0, 0.0, periapsis_speed, 0.0], 1.0e-6, 1.0e-9)
  end

  test "oscelt recovers the elements conics propagated" do
    mu = 398_600.435_436
    et = 60.0
    elts = [7_000.0, 0.01, 0.1, 0.2, 0.3, 0.4, 0.0, mu]
    mean_motion = :math.sqrt(mu / (7_000.0 / (1.0 - 0.01)) ** 3)

    assert {:ok, state} = Astro.Ephemeris.conics(elts, et)
    assert {:ok, [rp, ecc, inc, lnode, argp, m0, epoch, recovered_mu]} = Astro.Ephemeris.oscelt(state, et, mu)

    assert_in_delta rp, 7_000.0, 1.0e-6
    assert_in_delta ecc, 0.01, 1.0e-12
    assert_in_delta inc, 0.1, 1.0e-12
    assert_in_delta lnode, 0.2, 1.0e-12
    assert_in_delta argp, 0.3, 1.0e-12
    # The elements are re-expressed at `et`, so mean anomaly advanced by n * et.
    assert_in_delta m0, 0.4 + mean_motion * et, 1.0e-10
    assert_in_delta epoch, et, 1.0e-12
    assert_in_delta recovered_mu, mu, 1.0e-6
  end

  defp assert_state(actual, expected, position_tolerance, velocity_tolerance) do
    actual
    |> Enum.zip(expected)
    |> Enum.with_index()
    |> Enum.each(fn {{value, reference}, index} ->
      tolerance = if index < 3, do: position_tolerance, else: velocity_tolerance
      assert_in_delta value, reference, tolerance, "component #{index}: #{value} vs #{reference}"
    end)

    assert length(actual) == length(expected)
  end

  defp degrees(radians), do: radians * 180.0 / :math.pi()
end
