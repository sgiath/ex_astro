defmodule Astro.Kernel do
  @moduledoc """
  Runtime SPICE kernel management.

  `:spice_kernels` is read from application env when the application starts.
  Missing configured files log a warning and skip; load them later with
  `load/1` once the files exist. This module is also the path for kernels
  downloaded after boot.

  The native library owns one process-wide CSPICE kernel pool. Kernel mutations
  and all other CSPICE calls are serialized by the native mutex. A failed
  `load/1` restores the prior pool before returning an error.

  `loaded/0` returns directly loaded paths as absolute paths. Paths pulled in by
  meta-kernels are returned exactly as CSPICE stored them and may be relative.
  """

  @max_path_bytes 255

  @doc """
  Load a SPICE kernel into the CSPICE kernel pool.

  The path is expanded so later `unload/1` and `loaded/0` match what was
  furnished. Paths longer than 255 bytes are rejected, as is a missing file.

  Loading the same directly furnished path again is idempotent. A path loaded
  only as a meta-kernel child is still furnished directly by this function.
  A failed load restores the pool to its prior state before returning.
  """
  @spec load(Path.t()) :: :ok | {:error, String.t()}
  def load(path) do
    path = Path.expand(path)

    with :ok <- validate_path_size(path),
         :ok <- validate_exists(path) do
      Astro.NIF.kernel_furnsh(path)
    end
  end

  @doc """
  Unload a SPICE kernel from the CSPICE kernel pool.

  The path is expanded to match a direct `load/1` call. Missing files are not
  rejected, so a deleted kernel can still be removed from the pool. Paths
  longer than 255 bytes are rejected.

  Transitive children named by a meta-kernel cannot be unloaded through their
  returned path; unload the top-level meta-kernel instead. CSPICE treats an
  absent path as a successful no-op.
  """
  @spec unload(Path.t()) :: :ok | {:error, String.t()}
  def unload(path) do
    path = Path.expand(path)

    with :ok <- validate_path_size(path) do
      Astro.NIF.kernel_unload(path)
    end
  end

  @doc """
  Unload every kernel from the CSPICE kernel pool.
  """
  @spec clear() :: :ok | {:error, String.t()}
  def clear do
    Astro.NIF.kernel_clear()
  end

  @doc """
  Return the kernels currently loaded in the CSPICE kernel pool.

  Directly loaded paths are expanded absolute paths. Meta-kernel children are
  returned exactly as CSPICE stored them and may be relative. Returns
  `{:error, message}` if SPICE cannot read the pool, like the other kernel
  operations.
  """
  @spec loaded() :: {:ok, [String.t()]} | {:error, String.t()}
  def loaded, do: Astro.NIF.kernel_list()

  defp validate_path_size(path) do
    if byte_size(path) <= @max_path_bytes do
      :ok
    else
      {:error, "kernel path exceeds 255 bytes: #{path}"}
    end
  end

  defp validate_exists(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "kernel file not found: #{path}"}
    end
  end
end
