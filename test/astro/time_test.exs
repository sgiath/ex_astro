defmodule Astro.TimeTest do
  use ExUnit.Case, async: true

  doctest Astro.Time

  test "dtf2d and jd2dt convert the J2000 epoch" do
    jd = Astro.Time.dtf2d(2000, 1, 1, 12, 0, 0.0)

    assert_in_delta Astro.Time.jd_to_float(jd), 2_451_545.0, 1.0e-12
    assert Astro.Time.jd2dt(jd) == {2000, 1, 1, 12, 0, 0, 0}
  end

  test "to_julian_date and to_datetime round trip a naive datetime" do
    datetime = ~N[2000-01-01 12:34:56.123456]

    julian_date = Astro.Time.to_julian_date(datetime)
    converted = Astro.Time.to_datetime(julian_date)

    assert_in_delta Astro.Time.jd_to_float(julian_date), 2_451_545.024260688, 1.0e-12
    assert NaiveDateTime.diff(converted, datetime, :microsecond) |> abs() <= 10
  end

  test "utc tai and tt conversions round trip" do
    utc = {2_451_545.0, 0.0}

    tai = Astro.Time.utc2tai(utc)
    tt = Astro.Time.tai2tt(tai)

    assert_in_delta Astro.Time.jd_to_float(tai), 2_451_545.00037037, 1.0e-12
    assert Astro.Time.jd_to_float(tt) > Astro.Time.jd_to_float(tai)

    roundtrip_utc =
      tai
      |> Astro.Time.tai2utc()
      |> Astro.Time.jd_to_float()

    roundtrip_tai =
      tt
      |> Astro.Time.tt2tai()
      |> Astro.Time.jd_to_float()

    assert_in_delta roundtrip_utc, Astro.Time.jd_to_float(utc), 1.0e-12

    assert_in_delta roundtrip_tai, Astro.Time.jd_to_float(tai), 1.0e-12
  end

  test "et and day second helpers are consistent" do
    assert Astro.Time.str2et("2000 JAN 01 12:00:00 TDB") == 0.0
    assert_in_delta Astro.Time.utc2et("2000-01-01T12:00:00"), 64.18392728473108, 1.0e-9

    julian_date = {2_451_545.0, 0.25}

    assert Astro.Time.day2sec(julian_date) == 21_600.0
    assert Astro.Time.sec2day(21_600.0) == julian_date
  end

  test "jd helpers provide explicit float interop" do
    assert Astro.Time.jd_from_float(2_451_545.0) == {2_451_545.0, 0.0}
    assert Astro.Time.jd_to_float({2_451_545.0, 0.25}) == 2_451_545.25
  end

  test "time functions reject invalid input types" do
    assert_raise FunctionClauseError, fn ->
      Astro.Time.jd2dt("2451545.0")
    end

    assert_raise FunctionClauseError, fn ->
      Astro.Time.utc2tai(2_451_545.0)
    end

    assert_raise FunctionClauseError, fn ->
      Astro.Time.tt2tdb({2_451_545.0, "0"})
    end

    assert_raise ArgumentError, fn ->
      Astro.Time.tdb2tt({2_451_545.0, 0.0}, :ut, 0.0, 0.0, 0.0)
    end

    assert_raise ArgumentError, fn ->
      Astro.Time.utc2et(123)
    end

    assert_raise ArgumentError, fn ->
      Astro.Time.str2et(123)
    end

    assert_raise ArgumentError, fn ->
      Astro.Time.unitim(0.0, :et, "TAI")
    end

    assert_raise FunctionClauseError, fn ->
      Astro.Time.day2sec("2451545.0")
    end
  end

  test "time functions reject invalid ERFA date values" do
    assert_raise ArgumentError, fn ->
      Astro.Time.dtf2d(2000, 13, 1, 12, 0, 0.0)
    end

    assert_raise ArgumentError, fn ->
      Astro.Time.dtf2d(2000, 1, 1, 12, 0, -1.0)
    end

    assert_raise ArgumentError, fn ->
      Astro.Time.jd2dt({1.0e12, 0.0})
    end

    assert_raise ArgumentError, fn ->
      Astro.Time.utc2tai({1.0e12, 0.0})
    end

    assert_raise ArgumentError, fn ->
      Astro.Time.tai2utc({1.0e12, 0.0})
    end
  end

  test "dubious ERFA years still produce usable values" do
    jd = Astro.Time.dtf2d(2200, 1, 1, 0, 0, 0.0)

    assert match?({year, fraction} when is_float(year) and is_float(fraction), jd)

    assert match?(
             {year, fraction} when is_float(year) and is_float(fraction),
             Astro.Time.utc2tai(jd)
           )
  end

  test "tt2tdb and tdb2tt closely track SPICE uniform-scale conversions" do
    for tt <- [
          {2_451_544.5, 0.0},
          {2_451_545.0, 0.0},
          {2_451_545.0, 0.25},
          {2_460_000.0, 0.123456}
        ] do
      expected_tdb =
        tt
        |> Astro.Time.jd_to_float()
        |> Astro.Time.unitim("JDTDT", "JDTDB")
        |> Astro.Time.jd_from_float()

      actual_tdb =
        tt
        |> Astro.Time.tt2tdb()
        |> Astro.Time.jd_to_float()

      actual_tt =
        expected_tdb
        |> Astro.Time.tdb2tt()
        |> Astro.Time.jd_to_float()

      assert_in_delta actual_tdb, Astro.Time.jd_to_float(expected_tdb), 1.0e-9

      assert_in_delta actual_tt, Astro.Time.jd_to_float(tt), 1.0e-9
    end
  end

  test "observer-aware tt2tdb and tdb2tt accept topocentric ERFA arguments" do
    tt = {2_460_000.0, 0.123456}
    ut = 43_210.0
    elong = 0.7
    u = 4_500.0
    v = 4_400.0

    geocentric_tdb = Astro.Time.tt2tdb(tt)
    topocentric_tdb = Astro.Time.tt2tdb(tt, ut, elong, u, v)

    topocentric_tt =
      topocentric_tdb
      |> Astro.Time.tdb2tt(ut, elong, u, v)
      |> Astro.Time.jd_to_float()

    assert Astro.Time.tt2tdb(tt, 0.0, 0.0, 0.0, 0.0) == geocentric_tdb
    assert match?({tdb1, tdb2} when is_float(tdb1) and is_float(tdb2), topocentric_tdb)
    assert_in_delta topocentric_tt, Astro.Time.jd_to_float(tt), 1.0e-9
  end
end
