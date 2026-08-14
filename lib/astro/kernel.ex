defmodule Astro.Kernel do
  @moduledoc """
  Runtime SPICE kernel management.

  `:spice_kernels` is read from application env when the application starts.
  Missing configured files log a warning and skip; load them later with
  `load/1` once the files exist. This module is also the path for kernels
  downloaded after boot.

  Each of the four NIF shared objects used by `Astro.Support`,
  `Astro.Ephemeris`, `Astro.Time`, and `Astro.Star` statically links its own
  CSPICE copy with an independent kernel pool. `load/1`, `unload/1`, and
  `clear/0` fan every mutation across those pools **sequentially**. The fan-out is
  not atomic: concurrent Astro calls can observe intermediate pool state
  while a mutation is in progress. Use these functions only during
  application startup or another quiescent period when no Astro calls are
  running.

  `loaded/0` reports the Support shared object's pool. Directly loaded paths
  are absolute; paths pulled in by meta-kernels are returned exactly as CSPICE
  stored them and may be relative. This does not prove that the other three
  independent pools agree.
  """

  @nif_modules [Astro.Support, Astro.Ephemeris, Astro.Time.NIF, Astro.Star]
  @max_path_bytes 255

  @doc """
  Load a SPICE kernel into every NIF pool.

  The path is expanded so later `unload/1` and `loaded/0` match what was
  furnished. Paths longer than 255 bytes are rejected, as is a missing
  file.

  Loading the same directly furnished path again is idempotent. A path loaded
  only as a meta-kernel child is still furnished directly by this function.


  On failure, native furnsh restores the failing pool. Elixir unloads only
  pools newly changed by the current call, preserving earlier loads of the
  same path. Rollback failures are appended to the returned reason.

  Sequential and not atomic; call only while no Astro functions are
  running.
  """
  @spec load(Path.t()) :: :ok | {:error, String.t()}
  def load(path) do
    path = Path.expand(path)

    with :ok <- validate_path_size(path),
         :ok <- validate_exists(path) do
      furnish_all(path)
    end
  end

  @doc """
  Unload a SPICE kernel from every NIF pool.

  The path is expanded to match a direct `load/1` call. Missing files are not
  rejected, so a deleted kernel can still be removed from the pool. Paths
  longer than 255 bytes are rejected.

  Transitive children named by a meta-kernel cannot be unloaded through their
  returned path; unload the top-level meta-kernel instead. CSPICE treats an
  absent path as a successful no-op.

  Every pool is contacted even if one returns an error; the first error is
  returned. Sequential and not atomic; call only while no Astro functions are
  running.
  """
  @spec unload(Path.t()) :: :ok | {:error, String.t()}
  def unload(path) do
    path = Path.expand(path)

    with :ok <- validate_path_size(path) do
      each_pool(& &1.kernel_unload(path))
    end
  end

  @doc """
  Unload every kernel from every NIF pool.

  Sequential and not atomic; call only while no Astro functions are
  running.
  """
  @spec clear() :: :ok | {:error, String.t()}
  def clear do
    each_pool(& &1.kernel_clear())
  end

  @doc """
  Return the kernels currently loaded in the Support NIF pool.

  Directly loaded paths are expanded absolute paths. Meta-kernel children are
  returned exactly as CSPICE stored them and may be relative. This is an
  observation of one independent pool, not a cross-pool consistency check.
  """
  @spec loaded() :: [String.t()]
  def loaded do
    case Astro.Support.kernel_list() do
      {:ok, list} ->
        list

      {:error, reason} ->
        raise RuntimeError, "failed to list kernels: #{reason}"
    end
  end

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

  defp furnish_all(path) do
    result = Enum.reduce_while(@nif_modules, {:ok, []}, &furnish_pool(&1, path, &2))

    case result do
      {:ok, _changed} -> :ok
      {:error, reason, changed} -> rollback(changed, path, reason)
    end
  end

  defp furnish_pool(mod, path, {:ok, changed}) do
    case mod.kernel_loaded_direct(path) do
      true -> {:cont, {:ok, changed}}
      false -> furnish_new_pool(mod, path, changed)
      {:error, reason} -> {:halt, {:error, reason, changed}}
    end
  end

  defp furnish_new_pool(mod, path, changed) do
    case mod.kernel_furnsh(path) do
      :ok -> {:cont, {:ok, [mod | changed]}}
      {:error, reason} -> {:halt, {:error, reason, changed}}
    end
  end

  # The failing pool restores itself natively. Roll back only pools newly
  # changed by this call so an earlier load of the same path is preserved.
  defp rollback(changed, path, reason) do
    rollback_errors =
      Enum.flat_map(changed, fn mod ->
        case mod.kernel_unload(path) do
          :ok -> []
          {:error, rollback_reason} -> [{mod, rollback_reason}]
        end
      end)

    case rollback_errors do
      [] ->
        {:error, reason}

      errors ->
        detail =
          Enum.map_join(errors, "; ", fn {mod, rollback_reason} ->
            "#{inspect(mod)}: #{rollback_reason}"
          end)

        {:error, "#{reason}; rollback failed: #{detail}"}
    end
  end

  defp each_pool(fun) do
    @nif_modules
    |> Enum.map(fun)
    |> Enum.find(:ok, &match?({:error, _}, &1))
  end
end
