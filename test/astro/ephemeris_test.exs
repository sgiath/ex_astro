defmodule Astro.EphemerisTest do
  use ExUnit.Case, async: true

  doctest Astro.Ephemeris

  test "dirty scheduled state retrieval preserves success and error return shapes" do
    assert {:ok, state, light_time} =
             Astro.Ephemeris.spkezr("EARTH", 0.0, "J2000", "NONE", "SSB")

    assert length(state) == 6
    assert Enum.all?(state, &is_float/1)
    assert is_float(light_time)

    assert {:error, message} =
             Astro.Ephemeris.spkezr("NOT_A_BODY", 0.0, "J2000", "NONE", "SSB")

    assert is_binary(message)
    assert message =~ "NOT_A_BODY"
  end

  test "conics and oscelt accept fixed-size input lists" do
    mu = 398_600.435_436
    et = 60.0

    elts = [
      7_000.0,
      0.01,
      0.1,
      0.2,
      0.3,
      0.4,
      0.0,
      mu
    ]

    assert {:ok, state} = Astro.Ephemeris.conics(elts, et)
    assert length(state) == 6

    assert {:ok, round_trip_elts} = Astro.Ephemeris.oscelt(state, et, mu)
    assert length(round_trip_elts) == 8

    assert_in_delta Enum.at(round_trip_elts, 0), Enum.at(elts, 0), 1.0e-6
    assert_in_delta Enum.at(round_trip_elts, 1), Enum.at(elts, 1), 1.0e-12
    assert_in_delta Enum.at(round_trip_elts, 2), Enum.at(elts, 2), 1.0e-12
    assert_in_delta Enum.at(round_trip_elts, 3), Enum.at(elts, 3), 1.0e-12
    assert_in_delta Enum.at(round_trip_elts, 4), Enum.at(elts, 4), 1.0e-12
    assert_in_delta Enum.at(round_trip_elts, 6), et, 1.0e-12
    assert_in_delta Enum.at(round_trip_elts, 7), Enum.at(elts, 7), 1.0e-6
  end
end
