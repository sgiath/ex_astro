defmodule Astro.Star do
  @moduledoc """
  Propagate star-catalog entries and convert them to and from BCRS state vectors.

  Catalog data remains caller-owned. Functions accept ICRS right ascension and
  declination, proper motion, parallax, and radial velocity in the units used by
  ERFA. Epochs are two-part TDB Julian Dates in the same `{jd1, jd2}` form as
  `Astro.Time`.

  ERFA warnings are returned as a third tuple element rather than discarded:

  - `:distance_overridden` means ERFA increased the effective parallax because
    it was too small or the proper motion implied an unsafe transverse speed.
  - `:excessive_velocity` means ERFA replaced an excessive velocity with zero.
  - `:no_convergence` means the relativistic solution did not fully converge.

  ## Example

      iex> {:ok, state} =
      ...>   Astro.Star.starpv(4.702817062, 0.081886079, -3.9e-6, 5.02e-5, 0.54831, -110.6)
      iex> length(state)
      6
  """

  @type julian_date :: {float(), float()}
  @type catalog_entry :: {float(), float(), float(), float(), float(), float()}
  @type state_vector :: [float()]
  @type warning :: :distance_overridden | :excessive_velocity | :no_convergence
  @type result(value) :: {:ok, value} | {:ok, value, [warning()]} | {:error, atom()}

  @doc """
  Propagate a catalog entry between two TDB epochs using ERFA `eraPmsafe`.

  ## Input

    - `ra` and `dec` - ICRS right ascension and declination in radians.
    - `pmr` - rate of change of right ascension in radians per Julian year;
      this is the coordinate rate and is not multiplied by `cos(dec)`.
    - `pmd` - rate of change of declination in radians per Julian year.
    - `px` - parallax in arcseconds.
    - `rv` - radial velocity in km/s, positive when receding.
    - `ep1` and `ep2` - source and destination epochs as two-part TDB Julian
      Dates.

  ## Output

    - `{:ok, {ra2, dec2, pmr2, pmd2, px2, rv2}}` on success.
    - `{:ok, entry, warnings}` when ERFA adjusted input-derived data or the
      relativistic solution did not fully converge.
    - `{:error, reason}` on failure.

  ## Example

  Propagate Barnard's Star from the Hipparcos epoch to J2000:

      iex> result =
      ...>   Astro.Star.pmsafe(
      ...>     4.702817062,
      ...>     0.081886079,
      ...>     -3.9e-6,
      ...>     5.02e-5,
      ...>     0.54831,
      ...>     -110.6,
      ...>     {2_448_349.0625, 0.0},
      ...>     {2_451_545.0, 0.0}
      ...>   )
      iex> match?({:ok, {_, _, _, _, _, _}}, result)
      true

  More info at
  https://github.com/liberfa/erfa/blob/master/src/pmsafe.c
  """
  @spec pmsafe(
          float(),
          float(),
          float(),
          float(),
          float(),
          float(),
          julian_date(),
          julian_date()
        ) :: result(catalog_entry())
  def pmsafe(ra, dec, pmr, pmd, px, rv, ep1, ep2) do
    ra
    |> Astro.NIF.pmsafe(dec, pmr, pmd, px, rv, ep1, ep2)
    |> warning_result(:system_error)
  end

  @doc """
  Convert a catalog entry to a BCRS position and velocity vector using ERFA
  `eraStarpv`.

  ## Input

    - `ra` and `dec` - ICRS right ascension and declination in radians.
    - `pmr` and `pmd` - right-ascension and declination proper motions in
      radians per Julian year. `pmr` is not multiplied by `cos(dec)`.
    - `px` - parallax in arcseconds.
    - `rv` - radial velocity in km/s, positive when receding.

  ## Output

    - `{:ok, [x, y, z, vx, vy, vz]}` with position in au and velocity in
      au/day.
    - `{:ok, state, warnings}` when ERFA adjusted input-derived data or the
      relativistic solution did not fully converge.
    - `{:error, reason}` on failure.

  ## Example

  Convert Barnard's Star to a BCRS state vector:

      iex> {:ok, state} =
      ...>   Astro.Star.starpv(4.702817062, 0.081886079, -3.9e-6, 5.02e-5, 0.54831, -110.6)
      iex> Enum.all?(state, &is_float/1)
      true

  More info at
  https://github.com/liberfa/erfa/blob/master/src/starpv.c
  """
  @spec starpv(float(), float(), float(), float(), float(), float()) :: result(state_vector())
  def starpv(ra, dec, pmr, pmd, px, rv) do
    ra
    |> Astro.NIF.starpv(dec, pmr, pmd, px, rv)
    |> warning_result(:system_error)
  end

  @doc """
  Convert a BCRS position and velocity vector to catalog coordinates using
  ERFA `eraPvstar`.

  ## Input

    - `pv` - `[x, y, z, vx, vy, vz]`, with position in au and velocity in
      au/day.

  ## Output

    - `{:ok, {ra, dec, pmr, pmd, px, rv}}` with angles in radians, proper
      motions in radians per Julian year, parallax in arcseconds, and radial
      velocity in km/s.
    - `{:error, :superluminal_speed}` when the supplied speed is at least the
      speed of light.
    - `{:error, :null_position_vector}` when the position is zero.

  ## Example

  Round-trip Barnard's Star through a BCRS state vector:

      iex> {:ok, state} =
      ...>   Astro.Star.starpv(4.702817062, 0.081886079, -3.9e-6, 5.02e-5, 0.54831, -110.6)
      iex> {:ok, catalog_entry} = Astro.Star.pvstar(state)
      iex> tuple_size(catalog_entry)
      6

  More info at
  https://github.com/liberfa/erfa/blob/master/src/pvstar.c
  """
  @spec pvstar(state_vector()) :: {:ok, catalog_entry()} | {:error, atom()}
  def pvstar(pv) do
    case Astro.NIF.pvstar(pv) do
      {:ok, value, 0} -> {:ok, value}
      {:ok, _value, -1} -> {:error, :superluminal_speed}
      {:ok, _value, -2} -> {:error, :null_position_vector}
      {:ok, _value, _status} -> {:error, :system_error}
    end
  end

  defp warning_result({:ok, value, 0}, _negative_reason), do: {:ok, value}

  defp warning_result({:ok, value, status}, _negative_reason) when status > 0 do
    {:ok, value, warnings(status)}
  end

  defp warning_result({:ok, _value, _status}, negative_reason),
    do: {:error, negative_reason}

  defp warnings(status) do
    [
      {1, :distance_overridden},
      {2, :excessive_velocity},
      {4, :no_convergence}
    ]
    |> Enum.filter(fn {flag, _warning} -> Bitwise.band(status, flag) != 0 end)
    |> Enum.map(fn {_flag, warning} -> warning end)
  end
end
