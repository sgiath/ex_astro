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

  Existing files are kept, except `pck/earth_latest_high_prec.bpc`: NAIF
  updates it about twice a week, so every run downloads it again. Rerun the
  task regularly when you need current Earth orientation.

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

  # NAIF regenerates these in place under the same name (the Earth PCK about
  # twice a week, extending measured Earth orientation and its prediction),
  # so every run downloads them again. A failed refresh keeps the old file.
  @refreshed ["/pck/earth_latest_high_prec.bpc"]

  # Every SPICE kernel starts with an ID word naming its architecture and
  # type. Checking it keeps an error page served with HTTP 200, or one saved
  # by an older version of this task, from being used as a kernel.
  @id_words %{
    ".bsp" => "DAF/SPK ",
    ".bpc" => "DAF/PCK ",
    ".tls" => "KPL/LSK",
    ".tpc" => "KPL/PCK",
    ".tf" => "KPL/FK"
  }

  for path <- @kernels, not Map.has_key?(@id_words, Path.extname(path)) do
    raise "no SPICE ID word known for #{path}; add its extension to @id_words"
  end

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

    cond do
      path in @refreshed ->
        IO.puts("Refreshing #{path} ...")
        download(@base_url <> path, destination)

      File.exists?(destination) ->
        case check_id_word(destination, destination) do
          :ok ->
            IO.puts("File #{path} exists. Skipping")

          failure ->
            Mix.shell().error("File #{path} is unusable (#{failure_reason(failure)}); downloading it again")
            download(@base_url <> path, destination)
        end

      true ->
        IO.puts("Downloading #{path} ...")
        download(@base_url <> path, destination)
    end
  end

  # Stream into a file next to the destination and rename only after a
  # complete HTTP 200 response whose content starts with the kernel's ID word,
  # so a failed, interrupted or bogus download never leaves a file that a
  # later run would skip as already present. Streaming keeps gigabyte-sized
  # kernels such as jup365.bsp out of memory.
  defp download(url, destination) do
    partial = destination <> ".part"

    result =
      with :ok <- File.mkdir_p(Path.dirname(destination)),
           {:ok, %{status: 200}} <- stream_to_file(url, partial),
           :ok <- check_id_word(partial, destination) do
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

  # `kernel` names the kernel `file` should hold; a `.part` file has no type.
  defp check_id_word(file, kernel) do
    expected = Map.fetch!(@id_words, Path.extname(kernel))

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

  defp failure_reason({:ok, %{status: status}}), do: "HTTP #{status}"
  defp failure_reason({:error, exception}) when is_exception(exception), do: Exception.message(exception)
  defp failure_reason({:error, message}) when is_binary(message), do: message
  defp failure_reason({:error, posix}), do: List.to_string(:file.format_error(posix))

  defp start_req! do
    if !Code.ensure_loaded?(Req) do
      Mix.raise(~s(mix astro.kernels needs the optional :req dependency; add {:req, "~> 0.7"} to your deps))
    end

    {:ok, _apps} = Application.ensure_all_started(:req)
  end
end
