defmodule Astro.State do
  @moduledoc """
  Cartesian state of a body: its position and velocity relative to an observer.

  `position` is `{x, y, z}` in kilometers and `velocity` is `{vx, vy, vz}` in
  kilometers per second, the units the SPICE ephemeris works in. The state is
  expressed in the reference frame it was requested in; the struct does not
  record that frame, the observer, or the epoch, so the caller keeps track of
  them.
  """

  @type vec3 :: {float(), float(), float()}
  @type t :: %__MODULE__{position: vec3(), velocity: vec3()}

  @enforce_keys [:position, :velocity]
  defstruct [:position, :velocity]
end
