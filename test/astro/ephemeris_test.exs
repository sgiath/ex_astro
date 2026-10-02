defmodule Astro.EphemerisTest do
  use ExUnit.Case, async: true

  doctest Astro.Ephemeris

  # Reference values from JPL Horizons (DE441) for 2025-Nov-21 00:00:00 TDB
  # (JD 2461000.5), ICRF axes, km and km/s. The library loads DE442, whose
  # heliocentric Earth differs from DE441 here by 15 m and 2.5e-9 km/s.
  @et (2_461_000.5 - 2_451_545.0) * 86_400.0

  # Horizons VECTORS, COMMAND=399, CENTER=500@10, VEC_CORR=NONE
  @earth_from_sun %Astro.State{
    position: {7.708376725859748e7, 1.157075406782461e8, 5.015717517316379e7},
    velocity: {-2.591127972866548e1, 1.415542313920248e1, 6.136432087380158e0}
  }
  @earth_from_sun_lt 4.930195175071745e2

  # Horizons VECTORS, COMMAND=4, CENTER=500@399, VEC_CORR=LT
  @mars_from_earth_lt %Astro.State{
    position: {-1.145911228830736e8, -3.139674878149913e8, -1.400826126268110e8},
    velocity: {5.070522748540368e1, -1.576053773294104e1, -7.541410215861382e0}
  }
  @mars_from_earth_lt_lt 1.208818273597812e3

  # Horizons VECTORS, COMMAND=4, CENTER=500@399, VEC_CORR=LT+S (position only;
  # Horizons does not aberrate the velocity)
  @mars_from_earth_apparent_position {-1.146248934216085e8, -3.139571261392578e8, -1.400782065964461e8}

  test "spkezr geometric state matches JPL Horizons" do
    assert {:ok, %Astro.State{} = state, light_time} = Astro.Ephemeris.spkezr("EARTH", @et, "J2000", "NONE", "SUN")

    assert_state(state, @earth_from_sun, 5.0e-2, 1.0e-8)
    assert_in_delta light_time, @earth_from_sun_lt, 1.0e-8
  end

  test "spkez and spkgeo agree with Horizons for integer body IDs" do
    assert {:ok, %Astro.State{} = state, _light_time} = Astro.Ephemeris.spkez(399, @et, "J2000", "NONE", 10)
    assert_state(state, @earth_from_sun, 5.0e-2, 1.0e-8)

    assert {:ok, %Astro.State{} = state, light_time} = Astro.Ephemeris.spkgeo(399, @et, "J2000", 10)
    assert_state(state, @earth_from_sun, 5.0e-2, 1.0e-8)
    assert_in_delta light_time, @earth_from_sun_lt, 1.0e-8
  end

  test "light-time and stellar-aberration corrections match Horizons" do
    assert {:ok, state, light_time} = Astro.Ephemeris.spkezr("4", @et, "J2000", "LT", "399")

    # Horizons does not scale velocity by the light-time rate, SPICE does.
    assert_state(state, @mars_from_earth_lt, 2.0, 1.0e-4)
    assert_in_delta light_time, @mars_from_earth_lt_lt, 1.0e-5

    assert {:ok, apparent, _light_time} = Astro.Ephemeris.spkezr("4", @et, "J2000", "LT+S", "399")

    assert_vector(apparent.position, @mars_from_earth_apparent_position, 2.0, "position")
    # Stellar aberration moves the apparent position by ~34,000 km here.
    assert abs(elem(apparent.position, 0) - elem(state.position, 0)) > 30_000.0
  end

  test "spkezr reports unknown bodies" do
    assert {:error, message} = Astro.Ephemeris.spkezr("NOT_A_BODY", 0.0, "J2000", "NONE", "SSB")
    assert message =~ "NOT_A_BODY"
  end

  defp assert_state(%Astro.State{} = actual, %Astro.State{} = expected, position_tolerance, velocity_tolerance) do
    assert_vector(actual.position, expected.position, position_tolerance, "position")
    assert_vector(actual.velocity, expected.velocity, velocity_tolerance, "velocity")
  end

  defp assert_vector(actual, expected, tolerance, label) do
    for index <- 0..2 do
      value = elem(actual, index)
      reference = elem(expected, index)
      assert_in_delta value, reference, tolerance, "#{label} component #{index}: #{value} vs #{reference}"
    end
  end
end
