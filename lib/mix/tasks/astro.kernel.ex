defmodule Mix.Tasks.Astro.Kernels do
  @shortdoc "Downloads kernels for SPICE framework"

  @moduledoc """
  Download some general SPICE kernels to `priv/kernels/` of the current
  project. The full set is about 15 GB, most of it satellite ephemerides.

  Run it from the root of the application that should ship the kernels. The
  task prints a `config/runtime.exs` snippet that resolves the files with
  `Application.app_dir/2`, so the paths keep working in releases regardless
  of the working directory.

  Downloading uses the optional `:req` dependency; add `{:req, "~> 0.7"}` to
  your project's deps to run this task.

  If you want to download more kernels manually look here:
  https://naif.jpl.nasa.gov/pub/naif/generic_kernels/
  """

  use Mix.Task

  # Only configuration is needed; starting :ex_astro would load every
  # configured kernel before downloading them.
  @requirements ["app.config"]

  # :req is an optional dependency that only this task uses.
  @compile {:no_warn_undefined, [Req]}

  @base_url "https://naif.jpl.nasa.gov/pub/naif/generic_kernels"

  # SPICE gives the most recently loaded kernel priority where coverage
  # overlaps, so this list is ordered for loading: within a planetary system
  # the long-span older solutions come first and the newest solution last, and
  # the planetary ephemeris follows every satellite SPK so its Sun, Earth and
  # barycenter data win over the copies merged into the satellite files.
  @kernels [
    # comets
    "/spk/comets/c2013a1_s105_merged.bsp",

    # asteroids
    "/spk/asteroids/codes_300ast_20100725.bsp",

    # lagrange points
    "/spk/lagrange_point/L1_de441.bsp",
    "/spk/lagrange_point/L2_de441.bsp",
    "/spk/lagrange_point/L4_de441.bsp",
    "/spk/lagrange_point/L5_de441.bsp",

    # Mars satellites
    "/spk/satellites/mar099.bsp",

    # Jupiter satellites
    "/spk/satellites/jup347.bsp",
    "/spk/satellites/jup348.bsp",
    "/spk/satellites/jup349.bsp",
    "/spk/satellites/jup365.bsp",

    # Saturn satellites
    "/spk/satellites/sat393_daphnis.bsp",
    "/spk/satellites/sat415.bsp",
    "/spk/satellites/sat441.bsp",
    "/spk/satellites/sat455.bsp",
    "/spk/satellites/sat456.bsp",
    "/spk/satellites/sat457.bsp",
    "/spk/satellites/sat459.bsp",
    "/spk/satellites/sat480.bsp",

    # Uranus satellites
    "/spk/satellites/ura184_part-1.bsp",
    "/spk/satellites/ura184_part-2.bsp",
    "/spk/satellites/ura184_part-3.bsp",

    # Neptune satellites
    "/spk/satellites/nep097.bsp",
    "/spk/satellites/nep105.bsp",
    "/spk/satellites/nep104.bsp",
    "/spk/satellites/nep098_part-1.bsp",
    "/spk/satellites/nep098_part-2.bsp",
    "/spk/satellites/nep098_part-3.bsp",

    # Pluto satellites
    "/spk/satellites/plu060.bsp",

    # most up-to-date planets
    "/spk/planets/de442.bsp",

    # leap seconds
    "/lsk/naif0012.tls",
    "/lsk/latest_leapseconds.tls",

    # Planetary Constants Kernels
    "/pck/pck00011.tpc",
    "/pck/mars_iau2000_v1.tpc",
    "/pck/gm_de440.tpc",
    "/pck/moon_pa_de440_200625.bpc",
    "/pck/earth_latest_high_prec.bpc",

    # Frame Kernels
    # MOON_PA/MOON_ME frames for moon_pa_de440_200625.bpc
    "/fk/satellites/moon_de440_250416.tf",

    # names for satellite and asteroid IDs not built into CSPICE N0067
    "/fk/satellites/jup347_nameid.tf",
    "/fk/satellites/jup348_nameid.tf",
    "/fk/satellites/jup349_nameid.tf",
    "/fk/satellites/sat455_nameid.tf",
    "/fk/satellites/sat456_nameid.tf",
    "/fk/satellites/sat457_nameid.tf",
    "/fk/satellites/sat459_nameid.tf",
    "/fk/satellites/sat480_nameid.tf",
    "/fk/satellites/ura117_nameid.tf",
    "/fk/satellites/nep098_nameid.tf",
    "/fk/satellites/nep104_nameid.tf",
    "/spk/asteroids/codes_300ast_20100725.tf"
  ]

  @impl Mix.Task
  def run(_args) do
    start_req!()

    failures =
      Enum.flat_map(@kernels, fn path ->
        case fetch(path) do
          :ok -> []
          {:error, reason} -> [{path, reason}]
        end
      end)

    if failures != [] do
      Mix.raise("""
      Failed to download #{length(failures)} kernel(s); rerun the task to retry:
      #{Enum.map_join(failures, "\n", fn {path, reason} -> "  #{path}: #{reason}" end)}
      """)
    end

    app = Mix.Project.config()[:app]

    IO.puts("""


    #{IO.ANSI.green_background()}All kernels downloaded into the priv/ directory of #{inspect(app)}. Load them by adding this to config/runtime.exs:#{IO.ANSI.reset()}

    config :ex_astro,
      spice_kernels:
        for path <- [
    #{Enum.map_join(@kernels, ",\n", &"          \"priv/kernels#{&1}\"")}
            ],
            do: Application.app_dir(#{inspect(app)}, path)
    """)
  end

  defp fetch(path) do
    destination = "priv/kernels#{path}"

    if File.exists?(destination) do
      IO.puts("File #{path} exists. Skipping")
    else
      IO.puts("Downloading #{path} ...")
      download(@base_url <> path, destination)
    end
  end

  # Stream into a file next to the destination and rename only after a
  # complete HTTP 200 response, so a failed or interrupted download never
  # leaves a file that a later run would skip as already present. Streaming
  # keeps gigabyte-sized kernels such as jup365.bsp out of memory.
  defp download(url, destination) do
    partial = destination <> ".part"

    result =
      with :ok <- File.mkdir_p(Path.dirname(destination)),
           {:ok, %{status: 200}} <- stream_to_file(url, partial) do
        File.rename(partial, destination)
      end

    case result do
      :ok ->
        :ok

      failure ->
        File.rm(partial)
        {:error, failure_reason(failure)}
    end
  end

  # Req only streams 200 responses into the file; other bodies stay in memory.
  defp stream_to_file(url, path) do
    Req.get(url, decode_body: false, into: File.stream!(path))
  rescue
    error in File.Error -> {:error, error}
  end

  defp failure_reason({:ok, %{status: status}}), do: "HTTP #{status}"
  defp failure_reason({:error, exception}) when is_exception(exception), do: Exception.message(exception)
  defp failure_reason({:error, posix}), do: List.to_string(:file.format_error(posix))

  defp start_req! do
    if !Code.ensure_loaded?(Req) do
      Mix.raise(~s(mix astro.kernels needs the optional :req dependency; add {:req, "~> 0.7"} to your deps))
    end

    {:ok, _apps} = Application.ensure_all_started(:req)
  end
end
