defmodule Astro.Orbit do
  @moduledoc """
  Work with SPICE osculating conic orbital elements.

  An orbit is the conic that matches a body's position and velocity at one
  epoch: the path the body would follow if only its primary's gravity acted on
  it. The elements describe that instantaneous conic rather than a long-term
  perturbation model. Distances are expressed in kilometers, angles in radians,
  and epochs in Ephemeris Time (`ET`) seconds past J2000 TDB.

  `from_state/3` derives the elements from an `Astro.State` with SPICE's
  [`oscelt_c`](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/oscelt_c.html),
  `state_at/2` propagates them back to a state at any epoch with
  [`conics_c`](https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/conics_c.html),
  and `osculating/4` looks the state up in the loaded ephemeris first. To use
  known elements, build the struct directly:

      %Astro.Orbit{rp: 7_000.0, ecc: 0.01, inc: 0.1, lnode: 0.2, argp: 0.3, m0: 0.4, t0: 0.0, mu: 398_600.435_436}

  The struct fields follow SPICE's element order:

    - `rp` - perifocal distance (periapsis radius), km
    - `ecc` - eccentricity
    - `inc` - inclination, rad
    - `lnode` - longitude of the ascending node, rad
    - `argp` - argument of periapsis, rad
    - `m0` - mean anomaly at epoch, rad
    - `t0` - epoch, ET seconds; the instant at which the elements give the
      body's state
    - `mu` - gravitational parameter (GM) of the primary body, km^3/s^2

  The same elements describe all three types of conic orbit: elliptic,
  parabolic, and hyperbolic. The eight numeric fields are required when
  building the struct. `frame` names the SPICE reference frame the angular
  elements are measured in; it is `nil` when the orbit was built directly or
  from a state, whose frame the caller tracks.

  Functions that depend on a closed orbit - `apoapsis/1`, `mean_motion/1`,
  `period/1`, `mean_anomaly_at/2`, `eccentric_anomaly_at/2`, and
  `true_anomaly_at/2` - accept only elliptic orbits (`ecc < 1`) and raise
  `ArgumentError` for parabolic and hyperbolic ones.
  """

  alias Astro.Ephemeris
  alias Astro.NIF
  alias Astro.State
  alias Astro.Support

  # Bisection halves the bracket on every rejected Newton step, so 100
  # iterations covers far more than the 2^-52 relative spacing of a double.
  @kepler_max_iterations 100
  # Step size below which the estimate is accurate to double precision.
  @kepler_tolerance 1.0e-15

  @type t :: %__MODULE__{
          rp: float(),
          ecc: float(),
          inc: float(),
          lnode: float(),
          argp: float(),
          m0: float(),
          t0: float(),
          mu: float(),
          frame: String.t() | nil
        }

  @enforce_keys [:rp, :ecc, :inc, :lnode, :argp, :m0, :t0, :mu]
  defstruct @enforce_keys ++ [:frame]

  @doc """
  Derive osculating elements from a Cartesian state.

  `state` is the body's state relative to its primary at epoch `et` (ET
  seconds past J2000), in km and km/s. It must be expressed in an inertial
  reference frame; the elements are measured in that frame. `mu` is the
  primary's gravitational parameter in km^3/s^2. The returned orbit's epoch
  `t0` is `et` and its `frame` is `nil`.

  SPICE rejections, such as a non-positive `mu` or a zero position or velocity,
  return `{:error, message}`.

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/oscelt_c.html
  """
  @spec from_state(State.t(), float(), float()) :: {:ok, t()} | {:error, String.t()}
  def from_state(%State{position: {x, y, z}, velocity: {vx, vy, vz}}, et, mu) do
    with {:ok, [rp, ecc, inc, lnode, argp, m0, t0, elements_mu]} <- NIF.oscelt([x, y, z, vx, vy, vz], et, mu) do
      {:ok, %__MODULE__{rp: rp, ecc: ecc, inc: inc, lnode: lnode, argp: argp, m0: m0, t0: t0, mu: elements_mu}}
    end
  end

  @doc """
  Look up a target's state and derive its osculating orbit around an observer.

  The default frame is `"J2000"` and the default aberration correction is
  `"NONE"`. Pass `:mu` to override the observer's gravitational parameter;
  otherwise it is read from the loaded kernels with `Astro.Support.gm/1`.
  The returned orbit records the frame in its `frame` field.

  The frame must be inertial at `et`, because osculating elements are only
  defined for a state in an inertial frame. A rotating frame such as
  `"IAU_EARTH"` returns `{:error, "frame IAU_EARTH is not inertial"}`; SPICE
  errors for an unknown frame are returned as `{:error, message}`.

  Raises `ArgumentError` for options other than `:frame`, `:abcorr`, and `:mu`,
  and for a `:mu` that is not a float.
  """
  @spec osculating(String.t(), String.t(), float(), keyword()) ::
          {:ok, t()} | {:error, String.t()}
  def osculating(target, observer, et, opts \\ []) do
    opts = Keyword.validate!(opts, [:mu, frame: "J2000", abcorr: "NONE"])
    frame = Keyword.fetch!(opts, :frame)

    with :ok <- check_inertial(frame, et),
         {:ok, mu} <- resolve_mu(opts, observer),
         {:ok, state, _light_time} <- Ephemeris.spkezr(target, et, frame, opts[:abcorr], observer),
         {:ok, orbit} <- from_state(state, et, mu) do
      {:ok, %{orbit | frame: frame}}
    end
  end

  @doc """
  Propagate an orbit to an epoch and return its Cartesian state.

  `et` is the epoch of the returned state in ET seconds past J2000. The state
  is relative to the primary, in km and km/s, and expressed in the frame the
  elements are measured in. Elliptic, parabolic, and hyperbolic orbits are all
  supported.

  SPICE rejections, such as a non-positive `rp` or `mu` or a negative `ecc`,
  return `{:error, message}`.

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/conics_c.html
  """
  @spec state_at(t(), float()) :: {:ok, State.t()} | {:error, String.t()}
  def state_at(%__MODULE__{} = orbit, et) do
    elements = [orbit.rp, orbit.ecc, orbit.inc, orbit.lnode, orbit.argp, orbit.m0, orbit.t0, orbit.mu]

    with {:ok, [x, y, z, vx, vy, vz]} <- NIF.conics(elements, et) do
      {:ok, %State{position: {x, y, z}, velocity: {vx, vy, vz}}}
    end
  end

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

  Raises `ArgumentError` for a parabolic or hyperbolic orbit (`ecc >= 1`),
  which has no apoapsis.
  """
  @spec apoapsis(t()) :: float()
  def apoapsis(%__MODULE__{ecc: ecc}) when ecc >= 1.0 do
    raise ArgumentError, "open orbit has no apoapsis"
  end

  def apoapsis(%__MODULE__{rp: rp, ecc: ecc}), do: rp * (1.0 + ecc) / (1.0 - ecc)

  @doc """
  Return the mean motion in radians per second.

  Only elliptic orbits have a mean motion here; raises `ArgumentError` for a
  parabolic or hyperbolic orbit (`ecc >= 1`).
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

  Raises `ArgumentError` for a parabolic or hyperbolic orbit (`ecc >= 1`),
  which does not repeat.
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

  Uses `mean_motion/1`, so it raises `ArgumentError` for a parabolic or
  hyperbolic orbit (`ecc >= 1`).
  """
  @spec mean_anomaly_at(t(), float()) :: float()
  def mean_anomaly_at(%__MODULE__{m0: m0, t0: t0} = orbit, et) do
    normalize(m0 + mean_motion(orbit) * (et - t0))
  end

  @doc """
  Return the eccentric anomaly at an epoch.

  Uses `mean_anomaly_at/2`, so it raises `ArgumentError` for a parabolic or
  hyperbolic orbit (`ecc >= 1`).
  """
  @spec eccentric_anomaly_at(t(), float()) :: float()
  def eccentric_anomaly_at(%__MODULE__{ecc: ecc} = orbit, et) do
    mean_anomaly = mean_anomaly_at(orbit, et)
    eccentric_anomaly(mean_anomaly, ecc)
  end

  @doc """
  Return the true anomaly at an epoch.

  Uses `mean_anomaly_at/2`, so it raises `ArgumentError` for a parabolic or
  hyperbolic orbit (`ecc >= 1`).
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
  @spec perifocal_basis(t()) :: {State.vec3(), State.vec3(), State.vec3()}
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

  # A frame is inertial when its rotation to J2000 does not change with time:
  # the derivative block of the 6x6 state transformation (rows 3..5, columns
  # 0..2) is exactly zero.
  defp check_inertial(frame, et) do
    with {:ok, xform} <- NIF.sxform(frame, "J2000", et) do
      derivative = for row <- 3..5, column <- 0..2, do: Enum.at(xform, row * 6 + column)

      if Enum.all?(derivative, &(&1 == 0.0)) do
        :ok
      else
        {:error, "frame #{frame} is not inertial"}
      end
    end
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
