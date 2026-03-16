defmodule Astro.Ephemeris do
  @moduledoc """
  Calculation state of objects

  ## Aberration corrections

  Aberration correction argument in functions in this module may be any of the following:

  - `"NONE"` - Apply no correction. Return the geometric state of the target body relative to
    the observer.

  The following values of `abcorr` apply to the "reception" case in which photons depart from
  the target's location at the light-time corrected epoch et-lt and *arrive* at the observer's
  location at `et`:

  - `"LT"` - Correct for one-way light time (also called "planetary aberration") using a
    Newtonian formulation. This correction yields the state of the target at the moment it
    emitted photons arriving at the observer at `et`. The light time correction uses an
    iterative solution of the light time equation (see Particulars for details). The solution
    invoked by the "LT" option uses one iteration.

  - `"LT+S"` - Correct for one-way light time and stellar aberration using a Newtonian
    formulation. This option modifies the state obtained with the "LT" option to account for
    the observer's velocity relative to the solar system barycenter. The result is the
    apparent state of the target---the position and velocity of the target as seen by
    the observer.

  - `"CN"` - Converged Newtonian light time correction. In solving the light time equation,
    the "CN" correction iterates until the solution converges (three iterations on all
    supported platforms). Whether the "CN+S" solution is substantially more accurate than
    the "LT" solution depends on the geometry of the participating objects and on
    the accuracy of the input data. In all cases this routine will execute more slowly when
    a converged solution is computed. See the Particulars section below for a discussion of
    precision of light time corrections.

  - `"CN+S"` - Converged Newtonian light time correction and stellar aberration correction.

  The following values of `abcorr` apply to the "transmission" case in which photons *depart*
  from the observer's location at `et` and arrive at the target's location at the light-time
  corrected epoch et+lt:

  - `"XLT"` - "Transmission" case: correct for one-way light time using a Newtonian
    formulation. This correction yields the state of the target at the moment it receives
    photons emitted from the observer's location at `et`.

  - `"XLT+S"` - "Transmission" case: correct for one-way light time and stellar aberration
    using a Newtonian formulation  This option modifies the state obtained with the "XLT"
    option to account for the observer's velocity relative to the solar system barycenter.
    The position component of the computed target state indicates the direction that photons
    emitted from the observer's location must be "aimed" to hit the target.

  - `"XCN"` - "Transmission" case: converged Newtonian light time correction.

  - `"XCN+S"` - "Transmission" case: converged Newtonian light time correction and stellar
    aberration correction.

  Neither special nor general relativistic effects are accounted for in the aberration
  corrections applied by this routine.
  """
  use Astro.NIF, "ephemeris"

  require Logger

  @doc """
  Determine the apparent, true, or geometric state of a body with respect to another body relative
  to a user specified reference frame.

  Return the state (position and velocity) of a target body relative to an observing body,
  optionally corrected for light time (planetary aberration) and stellar aberration.

  ## Input

    - `target` - is the name of a target body. Optionally, you may supply the integer ID code for
      the object as an integer string. For example both "MOON" and "301" are legitimate strings that
      indicate the moon is the target body.

      The target and observer define a state vector whose position component points from
      the observer to the target.

    - `et` - is the ephemeris time, expressed as seconds past J2000 TDB, at which the state of
      the target body relative to the observer is to be computed. `et` refers to time at
      the observer's location.

    - `ref_plane` - is the name of the reference frame relative to which the output state vector
      should be expressed. This may be any frame supported by the SPICE system, including built-in
      frames (documented in the Frames Required Reading) and frames defined by a loaded frame kernel
      (FK).

      When `ref_plane` designates a non-inertial frame, the orientation of the frame is evaluated at
      an epoch dependent on the selected aberration correction. See the description of the output
      state vector `starg` for details.

    - `abcorr` - indicates the aberration corrections to be applied to the state of the target body
      to account for one-way light time and stellar aberration. See Aberration corrections section
      in module documentation.

    - `obs` - is the name of an observing body. Optionally, you may supply the ID code of the object
      as an integer string. For example, both "EARTH" and "399" are legitimate strings to supply to
      indicate the observer is Earth.

  ## Output

    - `state` - is a Cartesian state vector representing the position and velocity of the target
      body relative to the specified observer. `state` is corrected for the specified aberrations,
      and is expressed with respect to the reference frame specified by `ref`. The first three
      components of `state` represent the x, y and z-components of the target's position; the last
      three components form the corresponding velocity vector.

      The position component of `state` points from the observer's location at `et` to the
      aberration-corrected location of the target. Note that the sense of the position vector is
      independent of the direction of radiation travel implied by the aberration correction.

      The velocity component of `state` is the derivative with respect to time of the position
      component of `state`.

      Units are always km and km/sec.

      Non-inertial frames are treated as follows: letting `ltcent` be the one-way light time between
      the observer and the central body associated with the frame, the orientation of the frame is
      evaluated at et-ltcent, et+ltcent, or `et` depending on whether the requested aberration
      correction is, respectively, for received radiation, transmitted radiation, or is omitted.
      `ltcent` is computed using the method indicated by `abcorr`.

    - `lt` - is the one-way light time between the observer and target in seconds. If the target
      state is corrected for aberrations, then `lt` is the one-way light time between the observer
      and the light time corrected target location.

  ## Particulars

  This routine is part of the user interface to the SPICE ephemeris system. It allows you to
  retrieve state information for any ephemeris object relative to any other in a reference frame
  that is convenient for further computations.

  This routine is identical in function to the routine `spkez` except that it allows you to refer to
  ephemeris objects by name (via a character string).

  ## Example

  Get geometric state of Earth relative to Solar System Barycenter in the
  `J2000` frame at the J2000 epoch.

      iex> {:ok, state, lt} = Astro.Ephemeris.spkezr("EARTH", 0.0, "J2000", "NONE", "SSB")
      iex> length(state)
      6
      iex> is_float(lt)
      true

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/spkezr_c
  """
  @spec spkezr(
          target :: String.t(),
          et :: float(),
          ref_plane :: String.t(),
          abcorr :: String.t(),
          observer :: String.t()
        ) :: {:ok, state :: [float()], lt :: float()} | {:error, String.t()}
  def spkezr(target, et, ref_plane, ab_corr, observer)
      when is_binary(target) and is_float(et) and is_binary(ref_plane) and is_binary(ab_corr) and
             is_binary(observer),
      do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Determine the apparent, true, or geometric state of a body with respect to another body relative
  to a user specified reference frame.

  Return the state (position and velocity) of a target body relative to an observing body,
  optionally corrected for light time (planetary aberration) and stellar aberration.

  ## Example

  Get geometric state of Earth relative to Solar System Barycenter in the
  `J2000` frame at the J2000 epoch.

      iex> {:ok, state, lt} = Astro.Ephemeris.spkez(399, 0.0, "J2000", "NONE", 0)
      iex> length(state)
      6
      iex> is_float(lt)
      true

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/spkez_c
  """
  @spec spkez(
          target :: integer(),
          et :: float(),
          ref_plane :: String.t(),
          aberration_correction :: String.t(),
          observer :: integer()
        ) :: {:ok, state :: [float()], lt :: float()} | {:error, String.t()}
  def spkez(_et, _target, _observer, _ref_plane, _ab_corr),
    do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Compute the geometric state (position and velocity) of a target body relative to an observing
  body.

  ## Example

  Get geometric state of Earth relative to Solar System Barycenter in the
  `J2000` frame at the J2000 epoch.

      iex> {:ok, state, lt} = Astro.Ephemeris.spkgeo(399, 0.0, "J2000", 0)
      iex> length(state)
      6
      iex> is_float(lt)
      true

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/spkgeo_c
  """
  @spec spkgeo(
          target :: integer(),
          et :: float(),
          ref_plane :: String.t(),
          observer :: integer()
        ) :: {:ok, state :: [float()], lt :: float()} | {:error, String.t()}
  def spkgeo(_et, _target, _observer, _ref_plane),
    do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Determine conic elements from state

  Determine the set of osculating conic orbital elements that corresponds to the state (position,
  velocity) of a body at some epoch.

  ## Input

  - `state` - is the state (position and velocity) of the body at some epoch. Components are x, y,
    z, dx/dt, dy/dt, dz/dt. `state` must be expressed relative to an inertial reference frame. Units
    are km and km/sec.

  - `et` - is the epoch of the input state, in ephemeris seconds past J2000.
  - `mu` - is the gravitational parameter (GM, km^3 / sec^2 ) of the primary body.

  ## Output

  - `elts` - are equivalent conic elements describing the orbit of the body around its primary. The
    elements are, in order:

        rp      Perifocal distance.
        ecc     Eccentricity.
        inc     Inclination.
        lnode   Longitude of the ascending node.
        argp    Argument of periapsis.
        m0      Mean anomaly at epoch.
        t0      Epoch.
        mu      Gravitational parameter.

    The epoch of the elements is the epoch of the input state. Units are km, rad, rad/sec. The same
    elements are used to describe all three types (elliptic, hyperbolic, and parabolic) of conic
    orbit.

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/oscelt_c
  """
  @spec oscelt(state :: [float()], et :: float(), mu :: float()) ::
          {:ok, elts :: [float()]} | {:error, String.t()}
  def oscelt(_state, _et, _mu), do: :erlang.nif_error({:error, :not_loaded})

  @doc """
  Determine state from conic elements

  Determine the state (position, velocity) of an orbiting body from a set of elliptic, hyperbolic,
  or parabolic orbital elements.

  ## Input

  - `elts` - are conic osculating elements describing the orbit of a body around a primary.
    The elements are, in order:

        RP      Perifocal distance.
        ECC     Eccentricity.
        INC     Inclination.
        LNODE   Longitude of the ascending node.
        ARGP    Argument of periapse.
        M0      Mean anomaly at epoch.
        T0      Epoch.
        MU      Gravitational parameter.

    Units are km, rad, rad/sec, km^3/sec^2.

    The epoch `T0` is given in ephemeris seconds past J2000. `T0` is the instant at which the state
    of the body is specified by the elements.

    The same elements are used to describe all three types (elliptic, hyperbolic, and parabolic)
    of conic orbit.

  - `et` - is the time at which the state of the orbiting body is to be determined, in ephemeris seconds
    J2000.

  ## Output

  - `state` - is the state (position and velocity) of the body at time `et`. Components are x, y, z,
    dx/dt, dy/dt, dz/dt.

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/conics_c
  """
  @spec conics(elts :: [float()], et :: float()) ::
          {:ok, state :: [float()]} | {:error, String.t()}
  def conics(_elts, _et), do: :erlang.nif_error({:error, :not_loaded})
end
