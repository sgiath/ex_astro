defmodule Astro.SupportTest do
  use ExUnit.Case, async: true

  # The moduledoc and name-translation examples use SPICE's built-in body
  # table; the others read catalog kernels.
  doctest Astro.Support, only: [:moduledoc, bodc2n: 1, bodn2c: 1]
  doctest Astro.Support, except: [:moduledoc, bodc2n: 1, bodn2c: 1], tags: [kernels: true]

  @many_values Enum.map(1..20, &(&1 * 1.0))
  @many_objects "test/fixtures/kernels/ex_astro_test_many_objects.bsp"

  @tag :kernels
  test "dirty scheduled SPK inspection preserves public return shape" do
    assert {:ok, ids} = Astro.Support.spkobj("priv/kernels/spk/planets/de442.bsp")

    assert 399 in ids
  end

  test "spkobj returns every object of an SPK with more IDs than the initial result cell" do
    assert {:ok, ids} = Astro.Support.spkobj(@many_objects)
    assert ids == Enum.to_list(1_000_001..1_001_025)
  end

  @tag :kernels
  test "body constants keep normal RADII values" do
    assert {:ok, [6378.1366, 6378.1366, 6356.7519]} = Astro.Support.bodvcd(399, "RADII")
    assert {:ok, [6378.1366, 6378.1366, 6356.7519]} = Astro.Support.bodvrd("EARTH", "RADII")
    assert {:ok, [6378.1366, 6378.1366, 6356.7519]} = Astro.Support.bodvrd("399", "RADII")
  end

  @tag :kernels
  test "GM lookup accepts body IDs and names" do
    assert {:ok, mu} = Astro.Support.gm(10)
    assert_in_delta mu, 132_712_440_041.0, 1.0e6
    assert Astro.Support.gm("SUN") == Astro.Support.gm(10)
    assert Astro.Support.gm(" SUN ") == Astro.Support.gm(10)
    assert Astro.Support.gm("10") == Astro.Support.gm(10)
  end

  test "GM lookup reports unknown bodies" do
    assert {:error, "body not found: NOT_A_BODY"} = Astro.Support.gm("NOT_A_BODY")
    assert {:error, "kernel variable not found: BODY-123456789_GM"} = Astro.Support.gm(-123_456_789)
  end

  test "GM lookup rejects a body with more than one GM value" do
    message = "GM for body 100001 has 2 values, expected 1"

    assert {:error, ^message} = Astro.Support.gm(100_001)
    assert {:error, "GM for body EX_ASTRO_TEST_BODY has 2 values, expected 1"} = Astro.Support.gm("EX_ASTRO_TEST_BODY")
    assert {:ok, [1.0, 2.0]} = Astro.Support.bodvcd(100_001, "GM")
  end

  test "body constants return numeric kernel-pool values larger than 16 entries" do
    assert {:ok, @many_values} = Astro.Support.bodvcd(100_001, "MANY")
    assert {:ok, @many_values} = Astro.Support.bodvrd("EX_ASTRO_TEST_BODY", "MANY")
  end

  test "body constants report missing and character-valued kernel variables" do
    assert {:error, "kernel variable not found: BODY-123456789_RADII"} = Astro.Support.bodvcd(-123_456_789, "RADII")
    assert {:error, "body not found: NOT_A_BODY"} = Astro.Support.bodvrd("NOT_A_BODY", "RADII")

    assert {:error, "kernel variable is not numeric: BODY100001_LABEL"} = Astro.Support.bodvcd(100_001, "LABEL")

    assert {:error, "kernel variable is not numeric: BODY100001_LABEL"} =
             Astro.Support.bodvrd("EX_ASTRO_TEST_BODY", "LABEL")
  end

  test "body name and code translation report unknown bodies" do
    assert {:error, "body not found: -123456789"} = Astro.Support.bodc2n(-123_456_789)
    assert {:error, "body not found: NOT_A_BODY"} = Astro.Support.bodn2c("NOT_A_BODY")
  end

  test "a kernel-defined body name of the maximum 36 characters round trips" do
    name = "EX_ASTRO_TEST_BODY_WITH_36_CHAR_NAME"
    assert String.length(name) == 36

    assert {:ok, 100_010} = Astro.Support.bodn2c(name)
    assert {:ok, ^name} = Astro.Support.bodc2n(100_010)
  end
end
