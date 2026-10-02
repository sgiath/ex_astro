defmodule Astro.Orbit do
  @moduledoc """
  Work with SPICE osculating orbital elements.

  Distances are expressed in kilometers, angles in radians, and epochs in
  Ephemeris Time (`ET`) seconds past J2000. The elements describe an
  instantaneous conic at their epoch rather than a long-term perturbation
  model.

  The struct fields follow the element order used by SPICE's
  [`oscelt_c`](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/oscelt_c.html):
  periapsis radius, eccentricity, inclination, longitude of the ascending node,
  argument of periapsis, mean anomaly at epoch, epoch, and gravitational
  parameter.
  """

  alias Astro.Ephemeris
  alias Astro.Support

  # Bisection halves the bracket on every rejected Newton step, so 100
  # iterations covers far more than the 2^-52 relative spacing of a double.
  @kepler_max_iterations 100
  # Step size below which the estimate is accurate to double precision.
  @kepler_tolerance 1.0e-15

  @type vec3 :: {float(), float(), float()}
  @type t :: %__MODULE__{
          rp: float(),
          ecc: float(),
          inc: float(),
          lnode: float(),
          argp: float(),
          m0: float(),
          t0: float(),
          mu: float()
        }

  defstruct [:rp, :ecc, :inc, :lnode, :argp, :m0, :t0, :mu]

  @doc """
  Build an orbit from the eight elements returned by `Astro.Ephemeris.oscelt/3`.
  """
  @spec from_elements([float()]) :: t()
  def from_elements([rp, ecc, inc, lnode, argp, m0, t0, mu])
      when is_float(rp) and is_float(ecc) and is_float(inc) and is_float(lnode) and is_float(argp) and is_float(m0) and
             is_float(t0) and is_float(mu) do
    %__MODULE__{
      rp: rp,
      ecc: ecc,
      inc: inc,
      lnode: lnode,
      argp: argp,
      m0: m0,
      t0: t0,
      mu: mu
    }
  end

  @doc """
  Return the orbit's elements in the order expected by `Astro.Ephemeris.conics/2`.
  """
  @spec to_elements(t()) :: [float()]
  def to_elements(%__MODULE__{} = orbit) do
    [
      orbit.rp,
      orbit.ecc,
      orbit.inc,
      orbit.lnode,
      orbit.argp,
      orbit.m0,
      orbit.t0,
      orbit.mu
    ]
  end

  @doc """
  Derive osculating elements from a Cartesian state vector.
  """
  @spec from_state([float()], float(), float()) :: {:ok, t()} | {:error, String.t()}
  def from_state(state, et, mu) do
    with {:ok, elements} <- Ephemeris.oscelt(state, et, mu) do
      {:ok, from_elements(elements)}
    end
  end

  @doc """
  Look up a target's state and derive its osculating orbit around an observer.

  The default frame is `"J2000"` and the default aberration correction is
  `"NONE"`. Pass `:mu` to override the observer's gravitational parameter;
  otherwise it is read from the loaded kernels with `Astro.Support.gm/1`.
  """
  @spec osculating(String.t(), String.t(), float(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def osculating(target, observer, et, opts \\ []) do
    frame = Keyword.get(opts, :frame, "J2000")
    abcorr = Keyword.get(opts, :abcorr, "NONE")

    with {:ok, mu} <- resolve_mu(opts, observer),
         {:ok, state, _light_time} <- Ephemeris.spkezr(target, et, frame, abcorr, observer) do
      from_state(state, et, mu)
    end
  end

  @doc """
  Propagate an orbit to an epoch and return its Cartesian state vector.
  """
  @spec state_at(t(), float()) :: {:ok, [float()]} | {:error, String.t()}
  def state_at(%__MODULE__{} = orbit, et), do: Ephemeris.conics(to_elements(orbit), et)

  @doc """
  Return the semi-major axis in kilometers.

  Hyperbolic orbits use the standard negative semi-major axis convention.
  """
  @spec semi_major_axis(t()) :: float()
  def semi_major_axis(%__MODULE__{ecc: 1.0}) do
    raise ArgumentError, "parabolic orbit (ecc = 1) has no semi-major axis"
  end

  def semi_major_axis(%__MODULE__{rp: rp, ecc: ecc}), do: rp / (1.0 - ecc)

  @doc """
  Return the periapsis radius in kilometers.
  """
  @spec periapsis(t()) :: float()
  def periapsis(%__MODULE__{rp: rp}), do: rp

  @doc """
  Return the apoapsis radius in kilometers.
  """
  @spec apoapsis(t()) :: float()
  def apoapsis(%__MODULE__{ecc: ecc}) when ecc >= 1.0 do
    raise ArgumentError, "open orbit has no apoapsis"
  end

  def apoapsis(%__MODULE__{rp: rp, ecc: ecc}), do: rp * (1.0 + ecc) / (1.0 - ecc)

  @doc """
  Return the mean motion in radians per second.
  """
  @spec mean_motion(t()) :: float()
  def mean_motion(%__MODULE__{ecc: ecc}) when ecc >= 1.0 do
    raise ArgumentError, "open orbit has no mean motion"
  end

  def mean_motion(%__MODULE__{mu: mu} = orbit) do
    semi_major_axis = semi_major_axis(orbit)
    :math.sqrt(mu / semi_major_axis ** 3)
  end

  @doc """
  Return the orbital period in seconds.
  """
  @spec period(t()) :: float()
  def period(%__MODULE__{ecc: ecc}) when ecc >= 1.0 do
    raise ArgumentError, "open orbit has no period"
  end

  def period(%__MODULE__{} = orbit), do: 2.0 * :math.pi() / mean_motion(orbit)

  @doc """
  Solve Kepler's equation for the eccentric anomaly of an elliptic orbit.

  Uses Newton's method safeguarded by bisection on the bracket
  `[M - e, M + e]`, so it converges for every eccentricity in `[0, 1)`,
  including near-parabolic orbits. The result is not normalized and stays
  within `e` of the mean anomaly.
  """
  @spec eccentric_anomaly(float(), float()) :: float()
  def eccentric_anomaly(mean_anomaly, ecc) when is_float(mean_anomaly) and is_float(ecc) and ecc >= 0.0 and ecc < 1.0 do
    # E - M = e sin(E) lies in [-e, e], and E - e sin(E) - M increases
    # monotonically, so this interval always contains exactly one root.
    initial = mean_anomaly + ecc * :math.sin(mean_anomaly)
    solve_kepler(mean_anomaly, ecc, initial, mean_anomaly - ecc, mean_anomaly + ecc, @kepler_max_iterations)
  end

  def eccentric_anomaly(_mean_anomaly, _ecc) do
    raise ArgumentError, "eccentric anomaly requires eccentricity in [0, 1)"
  end

  @doc """
  Convert eccentric anomaly to true anomaly for an elliptic orbit.
  """
  @spec true_anomaly(float(), float()) :: float()
  def true_anomaly(eccentric_anomaly, ecc)
      when is_float(eccentric_anomaly) and is_float(ecc) and ecc >= 0.0 and ecc < 1.0 do
    half_anomaly = eccentric_anomaly / 2.0

    2.0 *
      :math.atan2(
        :math.sqrt(1.0 + ecc) * :math.sin(half_anomaly),
        :math.sqrt(1.0 - ecc) * :math.cos(half_anomaly)
      )
  end

  def true_anomaly(_eccentric_anomaly, _ecc) do
    raise ArgumentError, "true anomaly requires eccentricity in [0, 1)"
  end

  @doc """
  Return the normalized mean anomaly at an epoch.
  """
  @spec mean_anomaly_at(t(), float()) :: float()
  def mean_anomaly_at(%__MODULE__{m0: m0, t0: t0} = orbit, et) do
    normalize(m0 + mean_motion(orbit) * (et - t0))
  end

  @doc """
  Return the eccentric anomaly at an epoch.
  """
  @spec eccentric_anomaly_at(t(), float()) :: float()
  def eccentric_anomaly_at(%__MODULE__{ecc: ecc} = orbit, et) do
    mean_anomaly = mean_anomaly_at(orbit, et)
    eccentric_anomaly(mean_anomaly, ecc)
  end

  @doc """
  Return the true anomaly at an epoch.
  """
  @spec true_anomaly_at(t(), float()) :: float()
  def true_anomaly_at(%__MODULE__{ecc: ecc} = orbit, et) do
    eccentric_anomaly = eccentric_anomaly_at(orbit, et)
    true_anomaly(eccentric_anomaly, ecc)
  end

  @doc """
  Return the perifocal basis vectors in the elements' reference frame.

  The tuple contains the unit vectors toward periapsis, 90 degrees ahead in the
  orbital plane, and normal to the orbital plane.
  """
  @spec perifocal_basis(t()) :: {vec3(), vec3(), vec3()}
  def perifocal_basis(%__MODULE__{argp: argp, lnode: lnode, inc: inc}) do
    cw = :math.cos(argp)
    sw = :math.sin(argp)
    co = :math.cos(lnode)
    so = :math.sin(lnode)
    ci = :math.cos(inc)
    si = :math.sin(inc)

    u = {cw * co - sw * so * ci, cw * so + sw * co * ci, sw * si}
    v = {-sw * co - cw * so * ci, -sw * so + cw * co * ci, cw * si}
    w = {so * si, -co * si, ci}

    {u, v, w}
  end

  defp resolve_mu(opts, observer) do
    case Keyword.fetch(opts, :mu) do
      {:ok, mu} when is_float(mu) -> {:ok, mu}
      {:ok, _mu} -> raise ArgumentError, ":mu must be a float"
      :error -> Support.gm(observer)
    end
  end

  defp solve_kepler(mean_anomaly, ecc, estimate, low, high, iterations_left) do
    residual = estimate - ecc * :math.sin(estimate) - mean_anomaly

    if residual == 0.0 do
      estimate
    else
      {low, high} = if residual < 0.0, do: {estimate, high}, else: {low, estimate}
      newton = estimate - residual / (1.0 - ecc * :math.cos(estimate))
      next = if newton > low and newton < high, do: newton, else: (low + high) / 2.0

      cond do
        abs(next - estimate) <= @kepler_tolerance * max(1.0, abs(estimate)) ->
          next

        iterations_left == 1 ->
          raise ArithmeticError,
                "Kepler solver did not converge for mean anomaly #{mean_anomaly}, eccentricity #{ecc}"

        true ->
          solve_kepler(mean_anomaly, ecc, next, low, high, iterations_left - 1)
      end
    end
  end

  defp normalize(anomaly) do
    two_pi = 2.0 * :math.pi()
    normalized = :math.fmod(anomaly, two_pi)

    cond do
      normalized > :math.pi() -> normalized - two_pi
      normalized <= -:math.pi() -> normalized + two_pi
      true -> normalized
    end
  end
end
