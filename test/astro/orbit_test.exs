defmodule Astro.OrbitTest do
  use ExUnit.Case, async: true

  doctest Astro.Orbit

  @mu 398_600.435_436
  @elements [7_000.0, 0.01, 0.1, 0.2, 0.3, 0.4, 0.0, @mu]

  test "element list round trips through the orbit struct" do
    orbit = Astro.Orbit.from_elements(@elements)
    assert Astro.Orbit.to_elements(orbit) == @elements
  end

  test "state vectors round trip through osculating elements" do
    orbit = Astro.Orbit.from_elements(@elements)

    assert {:ok, state} = Astro.Orbit.state_at(orbit, 60.0)
    assert {:ok, recovered} = Astro.Orbit.from_state(state, 60.0, @mu)

    assert_in_delta recovered.rp, orbit.rp, 1.0e-6
    assert_in_delta recovered.ecc, orbit.ecc, 1.0e-12
    assert_in_delta recovered.inc, orbit.inc, 1.0e-12
  end

  test "eccentric anomaly solves Kepler's equation" do
    assert Astro.Orbit.eccentric_anomaly(2.5, 0.0) == 2.5

    eccentric_anomaly = Astro.Orbit.eccentric_anomaly(2.5, 0.9)
    residual = eccentric_anomaly - 0.9 * :math.sin(eccentric_anomaly) - 2.5

    assert abs(residual) < 1.0e-12

    assert_raise ArgumentError, fn -> Astro.Orbit.eccentric_anomaly(2.5, 1.0) end
  end

  test "eccentric anomaly converges for near-parabolic and multi-revolution inputs" do
    for {mean_anomaly, ecc} <- [
          {0.067, 0.999},
          {0.001, 0.999999},
          {-0.001, 0.999999},
          {3.14159, 0.9999},
          {1.0e-12, 0.99},
          {25.0, 0.95}
        ] do
      eccentric_anomaly = Astro.Orbit.eccentric_anomaly(mean_anomaly, ecc)
      residual = eccentric_anomaly - ecc * :math.sin(eccentric_anomaly) - mean_anomaly

      assert abs(residual) < 1.0e-12, "M=#{mean_anomaly} e=#{ecc}: residual #{residual}"
      assert abs(eccentric_anomaly - mean_anomaly) <= ecc
    end
  end

  test "derived values describe elliptic orbits" do
    orbit = Astro.Orbit.from_elements(@elements)
    semi_major_axis = Astro.Orbit.semi_major_axis(orbit)
    expected_period = 2.0 * :math.pi() * :math.sqrt(semi_major_axis ** 3 / @mu)

    assert_in_delta semi_major_axis, 7_070.7071, 1.0e-3
    assert_in_delta Astro.Orbit.period(orbit), expected_period, 1.0e-9
  end

  test "closed-orbit values reject open orbits" do
    orbit = Astro.Orbit.from_elements(@elements)
    orbit = %{orbit | ecc: 1.2}

    assert_raise ArgumentError, fn -> Astro.Orbit.apoapsis(orbit) end
    assert_raise ArgumentError, fn -> Astro.Orbit.mean_motion(orbit) end
    assert_raise ArgumentError, fn -> Astro.Orbit.period(orbit) end
  end

  test "perifocal basis vectors are orthonormal" do
    orbit = Astro.Orbit.from_elements(@elements)
    {u, v, w} = Astro.Orbit.perifocal_basis(orbit)

    assert_in_delta norm(u), 1.0, 1.0e-12
    assert_in_delta norm(v), 1.0, 1.0e-12
    assert_in_delta norm(w), 1.0, 1.0e-12
    assert_in_delta dot(u, v), 0.0, 1.0e-12
    assert_in_delta dot(u, w), 0.0, 1.0e-12
    assert_in_delta dot(v, w), 0.0, 1.0e-12
  end

  test "zero orientation has the Cartesian basis" do
    orbit = Astro.Orbit.from_elements([7_000.0, 0.01, 0.0, 0.0, 0.0, 0.0, 0.0, @mu])
    {u, v, w} = Astro.Orbit.perifocal_basis(orbit)

    assert_vector(u, {1.0, 0.0, 0.0})
    assert_vector(v, {0.0, 1.0, 0.0})
    assert_vector(w, {0.0, 0.0, 1.0})
  end

  test "osculating derives Earth's heliocentric orbit" do
    assert {:ok, orbit} =
             Astro.Orbit.osculating("3", "10", 0.0, frame: "ECLIPJ2000")

    assert_in_delta Astro.Orbit.semi_major_axis(orbit) / 149_597_870.7, 1.0, 0.02
    assert_in_delta Astro.Orbit.period(orbit) / 86_400.0, 365.25, 3.6525

    assert {:ok, overridden} =
             Astro.Orbit.osculating("3", "10", 0.0,
               frame: "ECLIPJ2000",
               mu: 1.0e11
             )

    assert overridden.mu == 1.0e11
  end

  defp norm(vector), do: :math.sqrt(dot(vector, vector))

  defp dot({ax, ay, az}, {bx, by, bz}), do: ax * bx + ay * by + az * bz

  defp assert_vector({ax, ay, az}, {bx, by, bz}) do
    assert_in_delta ax, bx, 1.0e-12
    assert_in_delta ay, by, 1.0e-12
    assert_in_delta az, bz, 1.0e-12
  end
end
