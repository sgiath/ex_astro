defmodule Astro.Ephemeris do
  @moduledoc """
  Look up the state (position and velocity) of ephemeris objects from the loaded SPK kernels.

  Every lookup returns an `Astro.State` with the position in km and the velocity in km/s. To turn
  a state into orbital elements, or to propagate elements back to a state, use `Astro.Orbit`.

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

  Native string inputs must be non-empty binaries without embedded NUL bytes.
  Body names and body ID strings accept up to 36 bytes, frame names accept up
  to 26 bytes, and aberration correction names accept up to 5 bytes. Invalid
  native strings raise `ArgumentError`.
  """

  alias Astro.NIF
  alias Astro.State

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

    - `state` - is an `Astro.State` holding the position and velocity of the target body
      relative to the specified observer. `state` is corrected for the specified aberrations,
      and is expressed with respect to the reference frame specified by `ref_plane`. Its
      `position` is the `{x, y, z}` vector of the target's position in km; its `velocity` is
      the corresponding `{vx, vy, vz}` velocity vector in km/s.

      `state.position` points from the observer's location at `et` to the
      aberration-corrected location of the target. Note that the sense of the position vector is
      independent of the direction of radiation travel implied by the aberration correction.

      `state.velocity` is the derivative with respect to time of `state.position`.

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

      iex> {:ok, %Astro.State{position: {x, y, z}}, lt} = Astro.Ephemeris.spkezr("EARTH", 0.0, "J2000", "NONE", "SSB")
      iex> Float.round(:math.sqrt(x * x + y * y + z * z) / 149_597_870.7, 2)
      0.98
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
        ) :: {:ok, State.t(), lt :: float()} | {:error, String.t()}
  def spkezr(target, et, ref_plane, ab_corr, observer) do
    to_state(NIF.spkezr(target, et, ref_plane, ab_corr, observer))
  end

  @doc """
  Determine the apparent, true, or geometric state of a body with respect to another body relative
  to a user specified reference frame.

  Return the state (position and velocity) of a target body relative to an observing body,
  optionally corrected for light time (planetary aberration) and stellar aberration.

  This is `spkezr/5` with integer NAIF IDs for the target and observer; the returned
  `Astro.State` and light time are described there.

  ## Example

  Get geometric state of Earth relative to Solar System Barycenter in the
  `J2000` frame at the J2000 epoch.

      iex> {:ok, %Astro.State{position: {x, y, z}}, lt} = Astro.Ephemeris.spkez(399, 0.0, "J2000", "NONE", 0)
      iex> Float.round(:math.sqrt(x * x + y * y + z * z) / 149_597_870.7, 2)
      0.98
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
        ) :: {:ok, State.t(), lt :: float()} | {:error, String.t()}
  def spkez(target, et, ref_plane, ab_corr, observer) do
    to_state(NIF.spkez(target, et, ref_plane, ab_corr, observer))
  end

  @doc """
  Compute the geometric state (position and velocity) of a target body relative to an observing
  body.

  Returns the `Astro.State` of the target relative to the observer, with the position in km and
  the velocity in km/s, and the one-way light time in seconds. No aberration corrections are
  applied.

  ## Example

  Get geometric state of Earth relative to Solar System Barycenter in the
  `J2000` frame at the J2000 epoch.

      iex> {:ok, %Astro.State{position: {x, y, z}}, lt} = Astro.Ephemeris.spkgeo(399, 0.0, "J2000", 0)
      iex> Float.round(:math.sqrt(x * x + y * y + z * z) / 149_597_870.7, 2)
      0.98
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
        ) :: {:ok, State.t(), lt :: float()} | {:error, String.t()}
  def spkgeo(target, et, ref_plane, observer) do
    to_state(NIF.spkgeo(target, et, ref_plane, observer))
  end

  defp to_state({:ok, [x, y, z, vx, vy, vz], lt}), do: {:ok, %State{position: {x, y, z}, velocity: {vx, vy, vz}}, lt}
  defp to_state({:error, _message} = error), do: error
end
