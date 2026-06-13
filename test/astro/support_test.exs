defmodule Astro.SupportTest do
  use ExUnit.Case, async: true

  @many_values Enum.map(1..20, &(&1 * 1.0))

  test "dirty scheduled SPK inspection preserves public return shape" do
    assert {:ok, ids} = Astro.Support.spkobj("priv/kernels/spk/planets/de440.bsp")

    assert 399 in ids
  end

  test "body constants keep normal RADII values" do
    assert {:ok, [6378.1366, 6378.1366, 6356.7519]} = Astro.Support.bodvcd(399, "RADII")
    assert {:ok, [6378.1366, 6378.1366, 6356.7519]} = Astro.Support.bodvrd("EARTH", "RADII")
    assert {:ok, [6378.1366, 6378.1366, 6356.7519]} = Astro.Support.bodvrd("399", "RADII")
  end

  test "body constants return numeric kernel-pool values larger than 16 entries" do
    assert {:ok, @many_values} = Astro.Support.bodvcd(100_001, "MANY")
    assert {:ok, @many_values} = Astro.Support.bodvrd("EX_ASTRO_TEST_BODY", "MANY")
  end
end
