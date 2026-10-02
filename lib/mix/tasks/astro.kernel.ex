defmodule Mix.Tasks.Astro.Kernels do
  @shortdoc "Downloads kernels for SPICE framework"

  @moduledoc """
  Download some general SPICE kernels to the priv/kernels/ directory

  If you want to download more kernels manually look here:
  https://naif.jpl.nasa.gov/pub/naif/generic_kernels/
  """

  use Mix.Task

  @requirements ["app.start"]

  @base_url "https://naif.jpl.nasa.gov/pub/naif/generic_kernels"

  @kernels [
    # comets
    "/spk/comets/c2013a1_s105_merged.bsp",

    # asteroids
    "/spk/asteroids/codes_300ast_20100725.bsp",

    # lagrange points
    "/spk/lagrange_point/L1_de431.bsp",
    "/spk/lagrange_point/L2_de431.bsp",
    "/spk/lagrange_point/L4_de431.bsp",
    "/spk/lagrange_point/L5_de431.bsp",

    # Mars satellites
    "/spk/satellites/mar097.bsp",

    # Jupiter satellites
    "/spk/satellites/jup344.bsp",
    "/spk/satellites/jup346.bsp",
    "/spk/satellites/jup365.bsp",

    # Saturn satellites
    "/spk/satellites/sat393_daphnis.bsp",
    "/spk/satellites/sat415.bsp",
    "/spk/satellites/sat441.bsp",
    "/spk/satellites/sat452.bsp",
    "/spk/satellites/sat453.bsp",

    # Uranus satellites
    "/spk/satellites/ura111.bsp",
    "/spk/satellites/ura115.bsp",
    "/spk/satellites/ura116.bsp",

    # Neptune satellites
    "/spk/satellites/nep095.bsp",
    "/spk/satellites/nep097.bsp",
    "/spk/satellites/nep102.bsp",

    # Pluto satellites
    "/spk/satellites/plu058.bsp",

    # most up-to-date planets
    "/spk/planets/de440.bsp",

    # leap seconds
    "/lsk/naif0012.tls",
    "/lsk/latest_leapseconds.tls",

    # Planetary Constants Kernels
    "/pck/pck00011.tpc",
    "/pck/mars_iau2000_v1.tpc",
    "/pck/gm_de440.tpc",
    "/pck/moon_pa_de440_200625.bpc",
    "/pck/earth_latest_high_prec.bpc"
  ]

  @impl Mix.Task
  def run(_args) do
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

    IO.puts("""


    #{IO.ANSI.green_background()}All kernels downloaded, now you can put this in your config.exs:#{IO.ANSI.reset()}

    config :ex_astro,
      spice_kernels: [
    #{Enum.map_join(@kernels, ",\n", &"    \"priv/kernels#{&1}\"")}
      ]
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
           {:ok, %Req.Response{status: 200}} <- stream_to_file(url, partial) do
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

  defp failure_reason({:ok, %Req.Response{status: status}}), do: "HTTP #{status}"
  defp failure_reason({:error, exception}) when is_exception(exception), do: Exception.message(exception)
  defp failure_reason({:error, posix}), do: List.to_string(:file.format_error(posix))
end
