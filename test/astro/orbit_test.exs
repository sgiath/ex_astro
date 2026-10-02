defmodule Astro.OrbitTest do
  use ExUnit.Case, async: true

  doctest Astro.Orbit

  @mu 398_600.435_436
  @orbit %Astro.Orbit{rp: 7_000.0, ecc: 0.01, inc: 0.1, lnode: 0.2, argp: 0.3, m0: 0.4, t0: 0.0, mu: @mu}

  # Reference values from JPL Horizons (DE441) for 2025-Nov-21 00:00:00 TDB
  # (JD 2461000.5), ICRF axes.
  @horizons_et (2_461_000.5 - 2_451_545.0) * 86_400.0

  # Horizons ELEMENTS, COMMAND=399, CENTER=500@10, REF_PLANE=FRAME
  @horizons_keplerian_gm 1.3271283864171489e11
  @earth_elements %{
    rp: 1.471360441715657e8,
    ecc: 1.729459436739474e-2,
    inc_deg: 2.343615841937300e1,
    lnode_deg: 1.145081961082815e-3,
    argp_deg: 1.013110497390046e2,
    m0_deg: 3.185855008712534e2
  }

  test "from_state matches Horizons osculating elements" do
    {:ok, state, _light_time} = Astro.Ephemeris.spkezr("EARTH", @horizons_et, "J2000", "NONE", "SUN")

    assert {:ok, orbit} = Astro.Orbit.from_state(state, @horizons_et, @horizons_keplerian_gm)

    assert_in_delta orbit.rp, @earth_elements.rp, 1.0e-2
    assert_in_delta orbit.ecc, @earth_elements.ecc, 1.0e-10
    assert_in_delta degrees(orbit.inc), @earth_elements.inc_deg, 1.0e-8
    assert_in_delta degrees(orbit.lnode), @earth_elements.lnode_deg, 1.0e-8
    assert_in_delta degrees(orbit.argp), @earth_elements.argp_deg, 1.0e-6
    assert_in_delta degrees(orbit.m0), @earth_elements.m0_deg, 1.0e-6
    assert orbit.t0 == @horizons_et
    assert orbit.mu == @horizons_keplerian_gm
    assert orbit.frame == nil
  end

  test "state_at propagates analytic circular, elliptic, and hyperbolic orbits" do
    r = 7_000.0
    circular = %Astro.Orbit{rp: r, ecc: 0.0, inc: 0.0, lnode: 0.0, argp: 0.0, m0: 0.0, t0: 0.0, mu: @mu}
    circular_period = 2.0 * :math.pi() * :math.sqrt(r ** 3 / @mu)
    circular_speed = :math.sqrt(@mu / r)

    # A quarter revolution moves a circular equatorial orbit from +x to +y.
    assert {:ok, %Astro.State{} = state} = Astro.Orbit.state_at(circular, circular_period / 4.0)
    assert_state(state, {0.0, r, 0.0}, {-circular_speed, 0.0, 0.0})

    # Half a revolution after periapsis an ellipse is at apoapsis.
    ecc = 0.3
    a = r / (1.0 - ecc)
    ra = a * (1.0 + ecc)
    elliptic_period = 2.0 * :math.pi() * :math.sqrt(a ** 3 / @mu)
    apoapsis_speed = :math.sqrt(@mu * (2.0 / ra - 1.0 / a))

    assert {:ok, state} = Astro.Orbit.state_at(%{circular | ecc: ecc}, elliptic_period / 2.0)
    assert_state(state, {-ra, 0.0, 0.0}, {0.0, -apoapsis_speed, 0.0})

    # A hyperbola at periapsis moves perpendicular to the radius vector.
    ecc = 1.5
    periapsis_speed = :math.sqrt(@mu * (1.0 + ecc) / r)

    assert {:ok, state} = Astro.Orbit.state_at(%{circular | ecc: ecc, t0: 100.0}, 100.0)
    assert_state(state, {r, 0.0, 0.0}, {0.0, periapsis_speed, 0.0})
  end

  test "from_state recovers the elements state_at propagated" do
    et = 60.0
    mean_motion = :math.sqrt(@mu / (7_000.0 / (1.0 - 0.01)) ** 3)

    assert {:ok, state} = Astro.Orbit.state_at(@orbit, et)
    assert {:ok, recovered} = Astro.Orbit.from_state(state, et, @mu)

    assert_in_delta recovered.rp, 7_000.0, 1.0e-6
    assert_in_delta recovered.ecc, 0.01, 1.0e-12
    assert_in_delta recovered.inc, 0.1, 1.0e-12
    assert_in_delta recovered.lnode, 0.2, 1.0e-12
    assert_in_delta recovered.argp, 0.3, 1.0e-12
    # The elements are re-expressed at `et`, so mean anomaly advanced by n * et.
    assert_in_delta recovered.m0, 0.4 + mean_motion * et, 1.0e-10
    assert_in_delta recovered.t0, et, 1.0e-12
    assert_in_delta recovered.mu, @mu, 1.0e-6
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
    semi_major_axis = Astro.Orbit.semi_major_axis(@orbit)
    expected_period = 2.0 * :math.pi() * :math.sqrt(semi_major_axis ** 3 / @mu)

    assert_in_delta semi_major_axis, 7_070.7071, 1.0e-3
    assert_in_delta Astro.Orbit.period(@orbit), expected_period, 1.0e-9
  end

  test "closed-orbit values reject open orbits" do
    orbit = %{@orbit | ecc: 1.2}

    assert_raise ArgumentError, fn -> Astro.Orbit.apoapsis(orbit) end
    assert_raise ArgumentError, fn -> Astro.Orbit.mean_motion(orbit) end
    assert_raise ArgumentError, fn -> Astro.Orbit.period(orbit) end
  end

  test "apoapsis and semi-major axis follow conic geometry" do
    assert_in_delta Astro.Orbit.apoapsis(@orbit), 7_000.0 * 1.01 / 0.99, 1.0e-9
    assert_in_delta Astro.Orbit.semi_major_axis(%{@orbit | ecc: 1.5}), -14_000.0, 1.0e-9
    assert_raise ArgumentError, fn -> Astro.Orbit.semi_major_axis(%{@orbit | ecc: 1.0}) end
  end

  test "true anomaly follows the half-angle relation" do
    assert_in_delta Astro.Orbit.true_anomaly(0.0, 0.5), 0.0, 1.0e-15
    assert_in_delta Astro.Orbit.true_anomaly(:math.pi() / 2.0, 0.5), 2.0 * :math.pi() / 3.0, 1.0e-12
    assert_in_delta Astro.Orbit.true_anomaly(-:math.pi() / 2.0, 0.5), -2.0 * :math.pi() / 3.0, 1.0e-12
    assert_raise ArgumentError, fn -> Astro.Orbit.true_anomaly(1.0, 1.0) end
  end

  test "anomalies at an epoch agree with the propagated SPICE state" do
    orbit = %{@orbit | ecc: 0.3}
    period = Astro.Orbit.period(orbit)

    assert_in_delta Astro.Orbit.mean_anomaly_at(orbit, period), 0.4, 1.0e-9
    assert_in_delta Astro.Orbit.mean_anomaly_at(orbit, period / 2.0), 0.4 - :math.pi(), 1.0e-9

    for et <- [0.0, 1_000.0, period / 3.0, 0.9 * period] do
      {:ok, %Astro.State{position: position}} = Astro.Orbit.state_at(orbit, et)
      {u, v, _w} = Astro.Orbit.perifocal_basis(orbit)
      expected_true_anomaly = :math.atan2(dot(position, v), dot(position, u))

      eccentric_anomaly = Astro.Orbit.eccentric_anomaly_at(orbit, et)
      assert eccentric_anomaly == Astro.Orbit.eccentric_anomaly(Astro.Orbit.mean_anomaly_at(orbit, et), 0.3)
      assert_in_delta Astro.Orbit.true_anomaly_at(orbit, et), expected_true_anomaly, 1.0e-9
    end
  end

  test "perifocal basis vectors are orthonormal" do
    {u, v, w} = Astro.Orbit.perifocal_basis(@orbit)

    assert_in_delta norm(u), 1.0, 1.0e-12
    assert_in_delta norm(v), 1.0, 1.0e-12
    assert_in_delta norm(w), 1.0, 1.0e-12
    assert_in_delta dot(u, v), 0.0, 1.0e-12
    assert_in_delta dot(u, w), 0.0, 1.0e-12
    assert_in_delta dot(v, w), 0.0, 1.0e-12
  end

  test "zero orientation has the Cartesian basis" do
    orbit = %{@orbit | inc: 0.0, lnode: 0.0, argp: 0.0, m0: 0.0}
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
    assert orbit.frame == "ECLIPJ2000"
  end

  test "osculating records the default frame" do
    assert {:ok, orbit} = Astro.Orbit.osculating("3", "10", 0.0)
    assert orbit.frame == "J2000"
  end

  test "osculating rejects unknown options" do
    assert_raise ArgumentError, ~r/unknown keys \[:fram\]/, fn ->
      Astro.Orbit.osculating("3", "10", 0.0, fram: "ECLIPJ2000")
    end
  end

  defp assert_state(%Astro.State{position: position, velocity: velocity}, expected_position, expected_velocity) do
    for index <- 0..2 do
      assert_in_delta elem(position, index), elem(expected_position, index), 1.0e-6
      assert_in_delta elem(velocity, index), elem(expected_velocity, index), 1.0e-9
    end
  end

  defp degrees(radians), do: radians * 180.0 / :math.pi()

  defp norm(vector), do: :math.sqrt(dot(vector, vector))

  defp dot({ax, ay, az}, {bx, by, bz}), do: ax * bx + ay * by + az * bz

  defp assert_vector({ax, ay, az}, {bx, by, bz}) do
    assert_in_delta ax, bx, 1.0e-12
    assert_in_delta ay, by, 1.0e-12
    assert_in_delta az, bz, 1.0e-12
  end
end
