defmodule Astro.Kernel.Catalog do
  @moduledoc """
  The default set of NAIF generic kernels that `mix astro.kernels` downloads.

  `paths/0` lists the kernels relative to a kernel root (`priv/kernels/` for
  the mix task) in the order they should be loaded, `url/1` gives the NAIF
  download URL of each path, and `check_id_word/2` tells a real kernel from,
  for example, an HTML error page saved under a kernel's name.

  The catalog changes between ex_astro releases as NAIF publishes newer
  solutions and retires old ones. Projects that need a stable kernel set
  should list their kernels explicitly in `config :ex_astro, :spice_kernels`
  instead of deriving that list from `paths/0` at runtime.
  """

  @base_url "https://naif.jpl.nasa.gov/pub/naif/generic_kernels"

  # SPICE gives the most recently loaded kernel priority where coverage
  # overlaps, so this list is ordered for loading: within a planetary system
  # the long-span older solutions come first and the newest solution last, and
  # the planetary ephemeris follows every satellite SPK so its Sun, Earth and
  # barycenter data win over the copies merged into the satellite files.
  @paths [
    # comets
    "spk/comets/c2013a1_s105_merged.bsp",

    # asteroids
    "spk/asteroids/codes_300ast_20100725.bsp",

    # lagrange points
    "spk/lagrange_point/L1_de441.bsp",
    "spk/lagrange_point/L2_de441.bsp",
    "spk/lagrange_point/L4_de441.bsp",
    "spk/lagrange_point/L5_de441.bsp",

    # Mars satellites
    "spk/satellites/mar099.bsp",

    # Jupiter satellites
    "spk/satellites/jup347.bsp",
    "spk/satellites/jup348.bsp",
    "spk/satellites/jup349.bsp",
    "spk/satellites/jup365.bsp",

    # Saturn satellites
    "spk/satellites/sat393_daphnis.bsp",
    "spk/satellites/sat415.bsp",
    "spk/satellites/sat441.bsp",
    "spk/satellites/sat455.bsp",
    "spk/satellites/sat456.bsp",
    "spk/satellites/sat457.bsp",
    "spk/satellites/sat459.bsp",
    "spk/satellites/sat480.bsp",

    # Uranus satellites
    "spk/satellites/ura184_part-1.bsp",
    "spk/satellites/ura184_part-2.bsp",
    "spk/satellites/ura184_part-3.bsp",

    # Neptune satellites
    "spk/satellites/nep097.bsp",
    "spk/satellites/nep105.bsp",
    "spk/satellites/nep104.bsp",
    "spk/satellites/nep098_part-1.bsp",
    "spk/satellites/nep098_part-2.bsp",
    "spk/satellites/nep098_part-3.bsp",

    # Pluto satellites
    "spk/satellites/plu060.bsp",

    # most up-to-date planets
    "spk/planets/de442.bsp",

    # leap seconds
    "lsk/naif0012.tls",
    "lsk/latest_leapseconds.tls",

    # Planetary Constants Kernels
    "pck/pck00011.tpc",
    "pck/mars_iau2000_v1.tpc",
    "pck/gm_de440.tpc",
    "pck/moon_pa_de440_200625.bpc",
    "pck/earth_latest_high_prec.bpc",

    # Frame Kernels
    # MOON_PA/MOON_ME frames for moon_pa_de440_200625.bpc
    "fk/satellites/moon_de440_250416.tf",

    # names for satellite and asteroid IDs not built into CSPICE N0067
    "fk/satellites/jup347_nameid.tf",
    "fk/satellites/jup348_nameid.tf",
    "fk/satellites/jup349_nameid.tf",
    "fk/satellites/sat455_nameid.tf",
    "fk/satellites/sat456_nameid.tf",
    "fk/satellites/sat457_nameid.tf",
    "fk/satellites/sat459_nameid.tf",
    "fk/satellites/sat480_nameid.tf",
    "fk/satellites/ura117_nameid.tf",
    "fk/satellites/nep098_nameid.tf",
    "fk/satellites/nep104_nameid.tf",
    "spk/asteroids/codes_300ast_20100725.tf"
  ]

  # NAIF regenerates these in place under the same name (the Earth PCK about
  # twice a week, extending measured Earth orientation and its prediction),
  # so a downloader should fetch them again on every run.
  @refreshed ["pck/earth_latest_high_prec.bpc"]

  # Every SPICE kernel starts with an ID word naming its architecture and
  # type. Checking it keeps an error page served with HTTP 200, or one saved
  # by an older downloader, from being used as a kernel.
  @id_words %{
    ".bsp" => "DAF/SPK ",
    ".bpc" => "DAF/PCK ",
    ".tls" => "KPL/LSK",
    ".tpc" => "KPL/PCK",
    ".tf" => "KPL/FK"
  }

  for path <- @paths, not Map.has_key?(@id_words, Path.extname(path)) do
    raise "no SPICE ID word known for #{path}; add its extension to @id_words"
  end

  @doc """
  Returns the catalog kernel paths relative to the kernel root, in SPICE load
  order.

  SPICE gives later kernels priority where coverage overlaps, so load the
  paths in the returned order: the planetary ephemeris comes after every
  satellite, Lagrange point, comet and asteroid SPK.
  """
  @spec paths() :: [String.t()]
  def paths, do: @paths

  @doc """
  Returns the NAIF download URL of a catalog path.

      iex> Astro.Kernel.Catalog.url("lsk/naif0012.tls")
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/naif0012.tls"
  """
  @spec url(String.t()) :: String.t()
  def url(path), do: "#{@base_url}/#{path}"

  @doc """
  Returns `true` for catalog paths that NAIF regenerates in place, so an
  existing copy goes stale and should be downloaded again.
  """
  @spec refresh?(String.t()) :: boolean()
  def refresh?(path), do: path in @refreshed

  @doc """
  Checks that `file` starts with the SPICE ID word of the kernel type of
  `kernel_path`.

  The extension of `kernel_path`, not of `file`, selects the expected ID word,
  so a partial download such as `de442.bsp.part` can be checked against
  `spk/planets/de442.bsp`. Returns `{:error, message}` when the file is not
  such a kernel (for example an HTML error page) and `{:error, posix}` when it
  cannot be read. Raises `KeyError` if `kernel_path` has an extension that no
  catalog kernel uses.
  """
  @spec check_id_word(Path.t(), Path.t()) :: :ok | {:error, String.t() | File.posix()}
  def check_id_word(file, kernel_path) do
    expected = Map.fetch!(@id_words, Path.extname(kernel_path))

    case File.open(file, [:read, :binary], &IO.binread(&1, byte_size(expected))) do
      {:ok, ^expected} ->
        :ok

      {:ok, data} when is_binary(data) ->
        {:error, "not a SPICE kernel: starts with #{inspect(data)}, expected #{inspect(expected)}"}

      {:ok, :eof} ->
        {:error, "not a SPICE kernel: empty file"}

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
