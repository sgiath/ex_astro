defmodule Astro.Kernel.CatalogTest do
  use ExUnit.Case, async: true

  alias Astro.Kernel.Catalog

  @text_pck "test/fixtures/kernels/ex_astro_test_many_values.tpc"

  describe "check_id_word/2" do
    test "accepts a file whose ID word matches the kernel type" do
      assert Catalog.check_id_word(@text_pck, "pck/pck00011.tpc") == :ok
    end

    @tag :tmp_dir
    test "takes the kernel type from the kernel path, not a .part file name", %{tmp_dir: dir} do
      partial = Path.join(dir, "de442.bsp.part")
      File.write!(partial, "DAF/SPK " <> :binary.copy(<<0>>, 1016))

      assert Catalog.check_id_word(partial, "spk/planets/de442.bsp") == :ok
    end

    @tag :tmp_dir
    test "rejects an HTML error page", %{tmp_dir: dir} do
      page = Path.join(dir, "de442.bsp")
      File.write!(page, "<!DOCTYPE html><html><body>404 Not Found</body></html>")

      assert {:error, "not a SPICE kernel: " <> _detail} = Catalog.check_id_word(page, "spk/planets/de442.bsp")
    end

    test "rejects a kernel of another type" do
      assert {:error, "not a SPICE kernel: " <> _detail} = Catalog.check_id_word(@text_pck, "lsk/naif0012.tls")
    end

    test "reports a missing file" do
      assert Catalog.check_id_word("test/fixtures/kernels/missing.bsp", "spk/planets/de442.bsp") == {:error, :enoent}
    end
  end

  test "the planetary ephemeris loads after every other SPK so its data wins" do
    spks =
      for {"spk/" <> _ = path, index} <- Enum.with_index(Catalog.paths()), Path.extname(path) == ".bsp", do: {path, index}

    {planets, others} = Enum.split_with(spks, fn {path, _index} -> String.starts_with?(path, "spk/planets/") end)

    assert planets != []
    assert others != []
    assert Enum.max(Enum.map(others, &elem(&1, 1))) < Enum.min(Enum.map(planets, &elem(&1, 1)))
  end
end
