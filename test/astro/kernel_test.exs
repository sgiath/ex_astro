defmodule Astro.KernelTest do
  use ExUnit.Case, async: false

  @runtime_kernel "test/fixtures/kernels/ex_astro_test_runtime.tpc"
  @partial_kernel "test/fixtures/kernels/ex_astro_test_partial.tm"

  test "loads and unloads a kernel across every NIF pool" do
    path = Path.expand(@runtime_kernel)
    on_exit(fn -> Astro.Kernel.unload(path) end)

    assert {:error, _reason} = Astro.Support.bodvcd(100_002, "RUNTIME")

    assert :ok = Astro.Kernel.load(path)
    assert {:ok, [42.0]} = Astro.Support.bodvcd(100_002, "RUNTIME")
    assert path in Astro.Kernel.loaded()
    assert {:ok, time_kernels} = Astro.Time.NIF.kernel_list()
    assert path in time_kernels

    assert :ok = Astro.Kernel.unload(path)
    assert {:error, _reason} = Astro.Support.bodvcd(100_002, "RUNTIME")
    refute path in Astro.Kernel.loaded()
  end

  test "rejects a missing kernel without changing loaded kernels" do
    loaded = Astro.Kernel.loaded()
    path = Path.expand("test/fixtures/kernels/ex_astro_test_missing.tpc")

    assert {:error, "kernel file not found: " <> ^path} = Astro.Kernel.load(path)
    assert Astro.Kernel.loaded() == loaded
  end

  test "restores the existing pool after a partially failed meta-kernel load" do
    loaded = Astro.Kernel.loaded()
    path = Path.expand(@partial_kernel)
    on_exit(fn -> Astro.Kernel.unload(path) end)

    assert {:error, _reason} = Astro.Kernel.load(path)
    assert Astro.Kernel.loaded() == loaded
    assert {:error, _reason} = Astro.Support.bodvcd(100_002, "RUNTIME")
  end

  test "reloading a direct meta-kernel is idempotent" do
    directory =
      Path.join(System.tmp_dir!(), "ex_astro_kernel_#{System.unique_integer([:positive])}")

    child = Path.join(directory, "runtime.tpc")
    meta = Path.join(directory, "runtime.tm")
    File.mkdir_p!(directory)
    write_runtime_kernel(child)
    write_meta_kernel(meta, child)

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
    assert meta in Astro.Kernel.loaded()
  end

  test "a transitive child can also be furnished directly" do
    directory =
      Path.join(System.tmp_dir!(), "ex_astro_kernel_#{System.unique_integer([:positive])}")

    child = Path.join(directory, "runtime.tpc")
    meta = Path.join(directory, "runtime.tm")
    File.mkdir_p!(directory)
    write_runtime_kernel(child)
    write_meta_kernel(meta, child)

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

    assert path in Astro.Kernel.loaded()
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
