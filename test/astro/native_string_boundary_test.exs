defmodule Astro.NativeStringBoundaryTest do
  use ExUnit.Case, async: true

  @spk_file "priv/kernels/spk/planets/de440.bsp"

  describe "embedded NUL rejection" do
    test "rejects NULs before CSPICE can observe truncated strings" do
      assert_raise ArgumentError, fn ->
        Astro.Time.str2et("2000 JAN 01\0 12:00:00 TDB")
      end

      assert_raise ArgumentError, fn ->
        Astro.Support.spkobj(@spk_file <> "\0ignored")
      end

      assert_raise ArgumentError, fn ->
        Astro.Ephemeris.spkezr("EARTH\0MOON", 0.0, "J2000", "NONE", "SSB")
      end

      assert_raise ArgumentError, fn ->
        Astro.Ephemeris.spkgeo(399, 0.0, "J2000\0BAD", 0)
      end
    end
  end

  describe "oversize string rejection" do
    test "rejects strings over each native string category limit" do
      assert_raise ArgumentError, fn ->
        Astro.Ephemeris.spkezr(String.duplicate("A", 37), 0.0, "J2000", "NONE", "SSB")
      end

      assert_raise ArgumentError, fn ->
        Astro.Ephemeris.spkgeo(399, 0.0, String.duplicate("A", 27), 0)
      end

      assert_raise ArgumentError, fn ->
        Astro.Ephemeris.spkez(399, 0.0, "J2000", String.duplicate("A", 6), 0)
      end

      assert_raise ArgumentError, fn ->
        Astro.Support.spkobj(String.duplicate("a", 256))
      end

      assert_raise ArgumentError, fn ->
        Astro.Support.bodvcd(399, String.duplicate("A", 33))
      end

      assert_raise ArgumentError, fn ->
        Astro.Time.str2et(String.duplicate("1", 257))
      end

      assert_raise ArgumentError, fn ->
        Astro.Time.utc2et(String.duplicate("1", 81))
      end

      assert_raise ArgumentError, fn ->
        Astro.Time.unitim(0.0, String.duplicate("A", 6), "TAI")
      end
    end
  end
end
