defmodule Mix.Tasks.Astro.Kernels do
  @shortdoc "Downloads kernels for SPICE framework"

  @moduledoc """
  Download the default NAIF generic kernels listed by `Astro.Kernel.Catalog`
  to `priv/kernels/` of the current project. The full set is about 15 GB,
  most of it satellite ephemerides.

  Run it from the root of the application that should ship the kernels. The
  task prints a `config/runtime.exs` snippet that resolves the files with
  `Application.app_dir/2`, so the paths keep working in releases regardless
  of the working directory.

  Downloading uses the optional `:req` dependency; add `{:req, "~> 0.7"}` to
  your project's deps to run this task.

  Existing files are kept, except `pck/earth_latest_high_prec.bpc`: NAIF
  updates it about twice a week, so every run downloads it again. Rerun the
  task regularly when you need current Earth orientation.

  Every download must start with the SPICE ID word of its kernel type, and
  every kernel NAIF does not replace in place must also match the SHA-256
  pinned in `Astro.Kernel.Catalog`; a download that fails either check is
  discarded and reported as a failure. Existing files are only checked for
  their ID word, not re-hashed.

  If you want to download more kernels manually look here:
  https://naif.jpl.nasa.gov/pub/naif/generic_kernels/
  """

  use Mix.Task

  alias Astro.Kernel.Catalog

  # Only configuration is needed; starting :ex_astro would load every
  # configured kernel before downloading them.
  @requirements ["app.config"]

  # :req is an optional dependency that only this task uses.
  @compile {:no_warn_undefined, [Req]}

  @impl Mix.Task
  def run(_args) do
    start_req!()

    failures =
      Enum.flat_map(Catalog.paths(), fn path ->
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
    #{Enum.map_join(Catalog.paths(), ",\n", &"          \"priv/kernels/#{&1}\"")}
            ],
            do: Application.app_dir(#{inspect(app)}, path)
    """)
  end

  defp fetch(path) do
    destination = Path.join("priv/kernels", path)

    cond do
      # A failed refresh keeps the old file; download/2 only replaces it on success.
      Catalog.refresh?(path) ->
        IO.puts("Refreshing #{path} ...")
        download(path, destination)

      File.exists?(destination) ->
        case Catalog.check_id_word(destination, path) do
          :ok ->
            IO.puts("File #{path} exists. Skipping")

          failure ->
            Mix.shell().error("File #{path} is unusable (#{failure_reason(failure)}); downloading it again")
            download(path, destination)
        end

      true ->
        IO.puts("Downloading #{path} ...")
        download(path, destination)
    end
  end

  # Stream into a file next to the destination and rename only after a
  # complete HTTP 200 response whose content starts with the kernel's ID word
  # and matches its pinned SHA-256, so a failed, interrupted or bogus download
  # never leaves a file that a later run would skip as already present.
  # Streaming keeps gigabyte-sized kernels such as jup365.bsp out of memory.
  defp download(path, destination) do
    partial = destination <> ".part"

    result =
      with :ok <- File.mkdir_p(Path.dirname(destination)),
           {:ok, %{status: 200}} <- stream_to_file(Catalog.url(path), partial),
           :ok <- Catalog.check_id_word(partial, path),
           :ok <- Catalog.check_sha256(partial, path) do
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
  defp failure_reason({:error, message}) when is_binary(message), do: message
  defp failure_reason({:error, posix}), do: List.to_string(:file.format_error(posix))

  defp start_req! do
    if !Code.ensure_loaded?(Req) do
      Mix.raise(~s(mix astro.kernels needs the optional :req dependency; add {:req, "~> 0.7"} to your deps))
    end

    {:ok, _apps} = Application.ensure_all_started(:req)
  end
end
