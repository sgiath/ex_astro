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
    assert converted |> NaiveDateTime.diff(datetime, :microsecond) |> abs() <= 10
  end

  test "jd2dt rounds fractional day carry across midnight to the next date" do
    julian_date = {2_451_544.5, 0.9999999999999999}

    assert Astro.Time.jd2dt(julian_date) == {2000, 1, 2, 0, 0, 0, 0}
    assert Astro.Time.to_datetime(julian_date) == ~N[2000-01-02 00:00:00.000000]
  end

  test "jd2dt decodes times on a UTC leap-second day" do
    assert 2016 |> Astro.Time.dtf2d(12, 31, 12, 0, 0.0) |> Astro.Time.jd2dt() ==
             {2016, 12, 31, 12, 0, 0, 0}

    assert 2016 |> Astro.Time.dtf2d(12, 31, 23, 59, 59.0) |> Astro.Time.jd2dt() ==
             {2016, 12, 31, 23, 59, 59, 0}

    assert 2016 |> Astro.Time.dtf2d(12, 31, 23, 59, 60.5) |> Astro.Time.jd2dt() ==
             {2016, 12, 31, 23, 59, 60, 500_000}
  end

  test "to_datetime rejects the unrepresentable leap second" do
    leap_second = Astro.Time.dtf2d(2016, 12, 31, 23, 59, 60.5)

    assert_raise ArgumentError, ~r/leap second/, fn -> Astro.Time.to_datetime(leap_second) end
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

  test "SPICE failures report the short error code with the long message" do
    assert {:error, "SPICE(" <> _ = message} = Astro.Time.str2et("not a parseable spice time")
    assert message =~ ~r/^SPICE\(\w+\) -- \S/
  end

  test "datetime and ephemeris time helpers agree with SPICE and round trip" do
    assert_in_delta(
      Astro.Time.to_et(~U[2000-01-01 12:00:00Z]),
      Astro.Time.utc2et("2000-01-01T12:00:00"),
      1.0e-3
    )

    datetime = ~N[2026-08-14 00:00:00]

    converted =
      datetime
      |> Astro.Time.to_et()
      |> Astro.Time.from_et()

    assert converted |> NaiveDateTime.diff(datetime, :microsecond) |> abs() <= 10
  end

  test "to_julian_date and to_et convert offset DateTimes by their UTC instant" do
    utc = ~U[2000-01-01 12:00:00.250000Z]

    summer_time = %DateTime{
      year: 2000,
      month: 1,
      day: 1,
      hour: 15,
      minute: 0,
      second: 0,
      microsecond: {250_000, 6},
      utc_offset: 7_200,
      std_offset: 3_600,
      time_zone: "Test/Offset",
      zone_abbr: "TST"
    }

    assert Astro.Time.to_julian_date(summer_time) == Astro.Time.to_julian_date(utc)
    assert Astro.Time.to_et(summer_time) == Astro.Time.to_et(utc)
  end

  test "jd helpers provide explicit float interop" do
    assert Astro.Time.jd_from_float(2_451_545.0) == {2_451_545.0, 0.0}
    assert Astro.Time.jd_to_float({2_451_545.0, 0.25}) == 2_451_545.25
  end

  test "time functions reject invalid input types" do
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

  test "observer-aware tt2tdb and tdb2tt match the ERFA dtdb reference with UT in seconds" do
    # ERFA t_erfa_c.c t_dtdb: eraDtdb(2448939.5, 0.123, 0.76543, 5.0123,
    # 5525.242, 3190.0) = -0.1280368005936998991e-2 s, UT1 given as 0.76543 day.
    tt = {2_448_939.5, 0.123}
    ut = 0.76543 * 86_400.0
    elong = 5.0123
    u = 5_525.242
    v = 3_190.0

    {tdb1, tdb2} = Astro.Time.tt2tdb(tt, ut, elong, u, v)

    assert tdb1 == 2_448_939.5
    assert_in_delta (tdb2 - 0.123) * 86_400.0, -0.1280368005936998991e-2, 1.0e-11

    {tt1, tt2} = Astro.Time.tdb2tt({tdb1, tdb2}, ut, elong, u, v)

    assert tt1 == 2_448_939.5
    assert_in_delta tt2, 0.123, 1.0e-15
  end
end
