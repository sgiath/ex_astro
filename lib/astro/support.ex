defmodule Astro.Support do
  @moduledoc """
  Look up SPICE body metadata and inspect kernel contents.

  This module wraps a small set of SPICE support routines that are useful when
  translating between NAIF body names and IDs, reading physical constants from
  loaded kernels, and discovering which bodies are present in an SPK file.

  ## Common Uses

  - Translate between built-in or kernel-defined body names and NAIF IDs.
  - Read body constants such as radii from loaded PCK or text kernels.
  - Inspect an SPK file before requesting states from `Astro.Ephemeris`.

  ## Kernel Requirements

  - `bodc2n/1` and `bodn2c/1` work with SPICE's built-in body mappings and also
    honor additional mappings loaded from text kernels.
  - `bodvcd/2` and `bodvrd/2` read values from the SPICE kernel pool, so the
    relevant PCK or text kernel data must already be loaded.
  - `spkobj/1` inspects the SPK file path passed to it directly.
  - `bodvcd/2` and `bodvrd/2` size numeric result lists from the kernel-pool
    variable dimension at runtime.
  - `spkobj/1` grows its native result cell as needed up to 65,536 object IDs.
    Files above that bound return `{:error, "SPK object result exceeds supported capacity of 65536 IDs"}`.
  - Native string inputs must be non-empty binaries without embedded NUL bytes.
    Body names accept up to 36 bytes, kernel-pool item names accept up to
    32 bytes, and SPK file paths accept up to 255 bytes. Invalid native strings
    raise `ArgumentError`.

  ## Example

      iex> Astro.Support.bodn2c("EARTH")
      {:ok, 399}

      iex> Astro.Support.bodc2n(399)
      {:ok, "EARTH"}
  """

  @type naif_id :: integer()
  @type kernel_item :: String.t()
  @type spk_file :: String.t()

  @doc """
  Translate a NAIF body ID code to a body name.

  ## Input

    - `code` - NAIF integer ID code for a body, barycenter, spacecraft,
      asteroid, comet, or similar SPICE object.

  ## Output

    - `{:ok, name}` - canonical SPICE body name associated with the code.
    - `{:error, reason}` - returned when the code has no known body-name
      mapping.

  ## Particulars

  The mapping can come from SPICE's built-in ID table or from body definitions
  loaded at runtime through text kernels.

  ## Example

      iex> Astro.Support.bodc2n(399)
      {:ok, "EARTH"}

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/bodc2n_c.html
  """
  @spec bodc2n(naif_id()) :: {:ok, String.t()} | {:error, String.t()}
  def bodc2n(code), do: Astro.NIF.bodc2n(code)

  @doc """
  Translate a body name to its NAIF ID code.

  ## Input

    - `name` - SPICE body name such as `"EARTH"`, `"MOON"`, or a body name
      introduced by a loaded text kernel.

  ## Output

    - `{:ok, code}` - NAIF integer ID code for the body.
    - `{:error, reason}` - returned when the name is not known to SPICE.

  ## Particulars

  Name matching is handled by SPICE. Built-in mappings are always available,
  and runtime mappings loaded from kernels take precedence when applicable.

  ## Example

      iex> Astro.Support.bodn2c("EARTH")
      {:ok, 399}

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/bodn2c_c.html
  """
  @spec bodn2c(String.t()) :: {:ok, naif_id()} | {:error, String.t()}
  def bodn2c(name), do: Astro.NIF.bodn2c(name)

  @doc """
  Return the set of body IDs present in an SPK file.

  ## Input

    - `file` - path to an SPK kernel file.

  ## Output

    - `{:ok, ids}` - list of NAIF body IDs for which the SPK file contains
      ephemeris segments.
    - `{:error, reason}` - returned when the file cannot be read as a valid SPK.

  ## Particulars

  This is useful for exploring a kernel before calling ephemeris routines. The
  returned IDs can be converted to names with `bodc2n/1` when a mapping exists.
  The native result cell grows as needed up to 65,536 unique object IDs. If an
  SPK file exceeds that supported capacity, this function returns
  `{:error, "SPK object result exceeds supported capacity of 65536 IDs"}`.

  ## Example

      iex> {:ok, ids} = Astro.Support.spkobj("priv/kernels/spk/planets/de442.bsp")
      iex> is_list(ids)
      true

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/spkobj_c.html
  """
  @spec spkobj(spk_file()) :: {:ok, [naif_id()]} | {:error, String.t()}
  def spkobj(file), do: Astro.NIF.spkobj(file)

  @doc """
  Fetch numeric kernel-pool values for a body identified by NAIF ID.

  ## Input

    - `code` - NAIF body ID code.
    - `item` - kernel variable suffix such as `"RADII"`.

  ## Output

    - `{:ok, values}` - list of floating-point values associated with the body
      and item.
    - `{:error, reason}` - returned when the kernel variable cannot be found or
      cannot be read.

  ## Particulars

  This function is typically used with PCK data. For example, the pair
  `399` and `"RADII"` resolves to the kernel-pool variable `BODY399_RADII`.
  Numeric result capacity is based on the variable dimension reported by the
  kernel pool, so variables with more than 16 values are returned completely
  when native allocation succeeds.

  ## Example

      iex> Astro.Support.bodvcd(399, "RADII")
      {:ok, [6378.1366, 6378.1366, 6356.7519]}

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/bodvcd_c.html
  """
  @spec bodvcd(naif_id(), kernel_item()) :: {:ok, [float()]} | {:error, String.t()}
  def bodvcd(code, item), do: Astro.NIF.bodvcd(code, item)

  @doc """
  Fetch numeric kernel-pool values for a body identified by name.

  ## Input

    - `name` - SPICE body name such as `"EARTH"`.
    - `item` - kernel variable suffix such as `"RADII"`.

  ## Output

    - `{:ok, values}` - list of floating-point values associated with the body
      and item.
    - `{:error, reason}` - returned when the kernel variable cannot be found or
      cannot be read.

  ## Particulars

  This is the named-body variant of `bodvcd/2`. It is often the most convenient
  way to access body constants from loaded PCK kernels. Numeric result capacity
  is based on the variable dimension reported by the kernel pool, so variables
  with more than 16 values are returned completely when native allocation
  succeeds.

  ## Example

      iex> Astro.Support.bodvrd("EARTH", "RADII")
      {:ok, [6378.1366, 6378.1366, 6356.7519]}

  More info at
  https://naif.jpl.nasa.gov/pub/naif/toolkit_docs/C/cspice/bodvrd_c.html
  """
  @spec bodvrd(String.t(), kernel_item()) :: {:ok, [float()]} | {:error, String.t()}
  def bodvrd(name, item), do: Astro.NIF.bodvrd(name, item)

  @doc """
  Look up the gravitational parameter GM (km³/s²) of a body from loaded kernels.

  Accepts a NAIF integer ID, an integer-string ID such as `"10"`, or a body
  name such as `"SUN"`. A PCK containing GM values, such as `gm_de440.tpc`,
  must be loaded.
  """
  @spec gm(naif_id() | String.t()) :: {:ok, float()} | {:error, String.t()}
  def gm(code) when is_integer(code) do
    case bodvcd(code, "GM") do
      {:ok, [mu]} ->
        {:ok, mu}

      {:ok, values} ->
        {:error, "GM for body #{code} has #{length(values)} values, expected 1"}

      {:error, _reason} = error ->
        error
    end
  end

  def gm(name) when is_binary(name) do
    name = String.trim(name)

    if Regex.match?(~r/\A-?\d+\z/, name) do
      gm(String.to_integer(name))
    else
      with {:ok, code} <- bodn2c(name), do: gm(code)
    end
  end
end
