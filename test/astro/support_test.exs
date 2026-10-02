defmodule Astro.SupportTest do
  use ExUnit.Case, async: true

  doctest Astro.Support

  @many_values Enum.map(1..20, &(&1 * 1.0))

  test "dirty scheduled SPK inspection preserves public return shape" do
    assert {:ok, ids} = Astro.Support.spkobj("priv/kernels/spk/planets/de442.bsp")

    assert 399 in ids
  end

  test "body constants keep normal RADII values" do
    assert {:ok, [6378.1366, 6378.1366, 6356.7519]} = Astro.Support.bodvcd(399, "RADII")
    assert {:ok, [6378.1366, 6378.1366, 6356.7519]} = Astro.Support.bodvrd("EARTH", "RADII")
    assert {:ok, [6378.1366, 6378.1366, 6356.7519]} = Astro.Support.bodvrd("399", "RADII")
  end

  test "GM lookup accepts body IDs and names" do
    assert {:ok, mu} = Astro.Support.gm(10)
    assert_in_delta mu, 132_712_440_041.0, 1.0e6
    assert Astro.Support.gm("SUN") == Astro.Support.gm(10)
    assert Astro.Support.gm("10") == Astro.Support.gm(10)
    assert {:error, _reason} = Astro.Support.gm("NOT_A_BODY")
  end

  test "body constants return numeric kernel-pool values larger than 16 entries" do
    assert {:ok, @many_values} = Astro.Support.bodvcd(100_001, "MANY")
    assert {:ok, @many_values} = Astro.Support.bodvrd("EX_ASTRO_TEST_BODY", "MANY")
  end

  test "body name and code translation report unknown bodies" do
    assert {:error, "body not found"} = Astro.Support.bodc2n(-123_456_789)
    assert {:error, "body not found"} = Astro.Support.bodn2c("NOT_A_BODY")
  end
end
