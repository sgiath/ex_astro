defmodule Astro.StarTest do
  use ExUnit.Case, async: true

  doctest Astro.Star

  test "pmsafe matches the ERFA reference vector" do
    assert {:ok, result} =
             Astro.Star.pmsafe(
               1.234,
               0.789,
               1.0e-5,
               -2.0e-5,
               1.0e-2,
               10.0,
               {2_400_000.5, 48_348.5625},
               {2_400_000.5, 51_544.5}
             )

    {ra, dec, pmr, pmd, px, rv} = result

    assert_in_delta ra, 1.234087484501017061, 1.0e-12
    assert_in_delta dec, 0.7888249982450468567, 1.0e-12
    assert_in_delta pmr, 0.9996457663586073988e-5, 1.0e-12
    assert_in_delta pmd, -0.2000040085106754565e-4, 1.0e-16
    assert_in_delta px, 0.9999997295356830666e-2, 1.0e-12
    assert_in_delta rv, 10.38468380293920069, 1.0e-10
  end

  test "starpv matches the ERFA reference vector" do
    assert {:ok, result} =
             Astro.Star.starpv(
               0.01686756,
               -1.093989828,
               -1.78323516e-5,
               2.336024047e-6,
               0.74723,
               -21.6
             )

    expected = [
      {126_668.5912743160601, 1.0e-10},
      {2_136.792716839935195, 1.0e-12},
      {-245_251.2339876830091, 1.0e-10},
      {-0.4051854008955659551e-2, 1.0e-13},
      {-0.6253919754414777970e-2, 1.0e-15},
      {0.1189353714588109341e-1, 1.0e-13}
    ]

    assert length(result) == length(expected)

    result
    |> Enum.zip(expected)
    |> Enum.each(fn {actual, {wanted, tolerance}} ->
      assert_in_delta actual, wanted, tolerance
    end)
  end

  test "pvstar matches the ERFA reference vector" do
    pv = [
      126_668.5912743160601,
      2_136.792716839935195,
      -245_251.2339876830091,
      -0.4051854035740712739e-2,
      -0.6253919754866173866e-2,
      0.1189353719774107189e-1
    ]

    assert {:ok, result} = Astro.Star.pvstar(pv)
    {ra, dec, pmr, pmd, px, rv} = result

    assert_in_delta ra, 0.1686756e-1, 1.0e-12
    assert_in_delta dec, -1.093989828, 1.0e-12
    assert_in_delta pmr, -0.1783235160000472788e-4, 1.0e-16
    assert_in_delta pmd, 0.2336024047000619347e-5, 1.0e-16
    assert_in_delta px, 0.74723, 1.0e-12
    assert_in_delta rv, -21.60000010107306010, 1.0e-11
  end

  test "positive statuses return decoded warning atoms" do
    assert {:ok, _result, [:distance_overridden]} =
             Astro.Star.starpv(1.0, 0.5, 0.0, 0.0, 0.0, 0.0)

    assert {:ok, _result, [:distance_overridden]} =
             Astro.Star.pmsafe(
               1.0,
               0.5,
               0.0,
               0.0,
               0.0,
               0.0,
               {2_451_545.0, 0.0},
               {2_451_545.0, 365.25}
             )

    assert {:ok, _result, [:distance_overridden, :excessive_velocity]} =
             Astro.Star.starpv(1.0, 0.5, 0.0, 0.0, 0.0, 300_000.0)
  end

  test "pvstar returns errors for invalid state vectors" do
    assert Astro.Star.pvstar([0.0, 0.0, 0.0, 0.0, 0.0, 0.0]) ==
             {:error, :null_position_vector}

    assert Astro.Star.pvstar([1.0, 0.0, 0.0, 200.0, 0.0, 0.0]) ==
             {:error, :superluminal_speed}
  end

  test "pvstar rejects state vectors that are not proper six-element float lists" do
    for pv <- [
          [1.0, 0.0, 0.0, 0.0, 0.0],
          [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
          [1.0, 0.0, 0.0, 0.0, 0.0, 0.0 | 0.0],
          [1.0, 0.0, 0.0, 0.0, 0.0, 0]
        ] do
      assert_raise ArgumentError, fn -> Astro.Star.pvstar(pv) end
    end
  end
end
