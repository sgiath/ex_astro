defmodule Astro.KernelTest do
  use ExUnit.Case, async: false

  @runtime_kernel "test/fixtures/kernels/ex_astro_test_runtime.tpc"
  @partial_kernel "test/fixtures/kernels/ex_astro_test_partial.tm"

  test "loads and unloads a kernel" do
    path = Path.expand(@runtime_kernel)
    on_exit(fn -> Astro.Kernel.unload(path) end)

    assert {:error, _reason} = Astro.Support.bodvcd(100_002, "RUNTIME")

    assert :ok = Astro.Kernel.load(path)
    assert {:ok, [42.0]} = Astro.Support.bodvcd(100_002, "RUNTIME")
    assert path in loaded_kernels()

    assert :ok = Astro.Kernel.unload(path)
    assert {:error, _reason} = Astro.Support.bodvcd(100_002, "RUNTIME")
    refute path in loaded_kernels()
  end

  test "concurrent native furnishes of one path remain idempotent" do
    path = Path.expand(@runtime_kernel)
    unload_repeatedly(path, 32)
    on_exit(fn -> unload_repeatedly(path, 32) end)

    results =
      1..32
      |> Task.async_stream(fn _ -> Astro.NIF.kernel_furnsh(path) end,
        max_concurrency: 32,
        ordered: false,
        timeout: 10_000
      )
      |> Enum.to_list()

    assert Enum.all?(results, &match?({:ok, :ok}, &1))
    assert :ok = Astro.Kernel.unload(path)
    assert {:error, _reason} = Astro.Support.bodvcd(100_002, "RUNTIME")
    refute path in loaded_kernels()
  end

  test "rejects a missing kernel without changing loaded kernels" do
    loaded = loaded_kernels()
    path = Path.expand("test/fixtures/kernels/ex_astro_test_missing.tpc")

    assert {:error, "kernel file not found: " <> ^path} = Astro.Kernel.load(path)
    assert loaded_kernels() == loaded
  end

  test "restores loaded kernels after a partially failed meta-kernel load" do
    loaded = loaded_kernels()
    path = Path.expand(@partial_kernel)
    on_exit(fn -> Astro.Kernel.unload(path) end)

    assert {:error, _reason} = Astro.Kernel.load(path)
    assert loaded_kernels() == loaded
    assert {:error, _reason} = Astro.Support.bodvcd(100_002, "RUNTIME")
  end

  test "kernel mutations are atomic for concurrent readers" do
    runtime = Path.expand(@runtime_kernel)
    partial = Path.expand(@partial_kernel)
    on_exit(fn -> unload_repeatedly(runtime, 64) end)

    {:ok, earth_gm} = Astro.Support.bodvcd(399, "GM")
    {:ok, earth_state, _lt} = Astro.Ephemeris.spkezr("EARTH", 0.0, "J2000", "NONE", "SUN")

    jobs =
      List.duplicate(:failed_meta_kernel_load, 40) ++
        List.duplicate(:load_unrelated_kernel, 20) ++
        List.duplicate(:unload_unrelated_kernel, 20) ++
        List.duplicate(:read, 200)

    results =
      jobs
      |> Enum.shuffle()
      |> Task.async_stream(&run_job(&1, runtime, partial),
        max_concurrency: 2 * System.schedulers_online(),
        ordered: false,
        timeout: 30_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    for result <- results do
      case result do
        {:failed_meta_kernel_load, outcome} ->
          assert {:error, _reason} = outcome

        {:read, gm, state} ->
          assert gm == {:ok, earth_gm}
          assert {:ok, ^earth_state, _lt} = state

        {_mutation, outcome} ->
          assert outcome == :ok
      end
    end

    # Every failed meta-kernel load rolled back, so once the unrelated runtime
    # kernel is unloaded nothing defines its variable.
    unload_repeatedly(runtime, 64)
    assert {:error, _reason} = Astro.Support.bodvcd(100_002, "RUNTIME")
    refute partial in loaded_kernels()
  end

  test "reloading a direct meta-kernel is idempotent" do
    {directory, child, meta} = setup_meta_kernel()

    on_exit(fn ->
      write_runtime_kernel(child)
      Astro.Kernel.unload(meta)
      File.rm_rf!(directory)
    end)

    assert :ok = Astro.Kernel.load(meta)
    assert {:ok, [43.0]} = Astro.Support.bodvcd(100_003, "RELOAD")

    File.rm!(child)

    assert :ok = Astro.Kernel.load(meta)
    assert {:ok, [43.0]} = Astro.Support.bodvcd(100_003, "RELOAD")
    assert meta in loaded_kernels()
  end

  test "a transitive child can also be furnished directly" do
    {directory, child, meta} = setup_meta_kernel()

    on_exit(fn ->
      Astro.Kernel.unload(meta)
      Astro.Kernel.unload(child)
      File.rm_rf!(directory)
    end)

    assert :ok = Astro.Kernel.load(meta)
    assert :ok = Astro.Kernel.load(child)
    assert :ok = Astro.Kernel.load(child)
    assert :ok = Astro.Kernel.unload(meta)
    assert {:ok, [43.0]} = Astro.Support.bodvcd(100_003, "RELOAD")

    assert :ok = Astro.Kernel.unload(child)
    assert {:error, _reason} = Astro.Support.bodvcd(100_003, "RELOAD")
  end

  test "loads configured kernels when the application starts" do
    path = Path.expand("test/fixtures/kernels/ex_astro_test_many_values.tpc")

    assert path in loaded_kernels()
  end

  test "clear unloads every kernel" do
    previously_loaded = loaded_kernels()
    on_exit(fn -> Enum.each(previously_loaded, &(:ok = Astro.Kernel.load(&1))) end)

    assert :ok = Astro.Kernel.clear()
    assert loaded_kernels() == []
    assert {:error, _reason} = Astro.Support.bodvcd(399, "GM")
  end

  defp loaded_kernels do
    assert {:ok, paths} = Astro.Kernel.loaded()
    paths
  end

  defp run_job(:failed_meta_kernel_load, _runtime, partial), do: {:failed_meta_kernel_load, Astro.Kernel.load(partial)}
  defp run_job(:load_unrelated_kernel, runtime, _partial), do: {:load_unrelated_kernel, Astro.Kernel.load(runtime)}
  defp run_job(:unload_unrelated_kernel, runtime, _partial), do: {:unload_unrelated_kernel, Astro.Kernel.unload(runtime)}

  defp run_job(:read, _runtime, _partial) do
    {:read, Astro.Support.bodvcd(399, "GM"), Astro.Ephemeris.spkezr("EARTH", 0.0, "J2000", "NONE", "SUN")}
  end

  defp unload_repeatedly(path, count) do
    Enum.each(1..count, fn _ -> Astro.Kernel.unload(path) end)
  end

  defp setup_meta_kernel do
    directory =
      Path.join(System.tmp_dir!(), "ex_astro_kernel_#{System.unique_integer([:positive])}")

    child = Path.join(directory, "runtime.tpc")
    meta = Path.join(directory, "runtime.tm")
    File.mkdir_p!(directory)
    write_runtime_kernel(child)
    write_meta_kernel(meta, child)
    {directory, child, meta}
  end

  defp write_runtime_kernel(path) do
    File.write!(
      path,
      "KPL/PCK\n\n\\begindata\n\nBODY100003_RELOAD = ( 43.0 )\n\n\\begintext\n"
    )
  end

  defp write_meta_kernel(path, child) do
    File.write!(
      path,
      "KPL/MK\n\n\\begindata\n\nKERNELS_TO_LOAD = ( '#{child}' )\n\n\\begintext\n"
    )
  end
end
