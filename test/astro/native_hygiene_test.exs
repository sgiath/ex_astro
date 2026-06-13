defmodule Astro.NativeHygieneTest do
  use ExUnit.Case, async: true

  test "shared NIF utilities document ownership and reject VLA list construction" do
    utils = File.read!("c_src/utils.h")

    assert utils =~ "#ifndef EX_ASTRO_UTILS_H"
    assert utils =~ "shared object its own CSPICE mutex/error/kernel ownership"
    refute utils =~ ~r/ERL_NIF_TERM\s+\w+\s*\[\s*len\s*\]/
    assert utils =~ "enif_make_list_cell"
  end

  test "native build warning policy stays focused on first-party C sources" do
    makefile = File.read!("Makefile")

    assert makefile =~ "-Wstrict-prototypes"
    assert makefile =~ "-Wold-style-definition"
    assert makefile =~ "-Wint-conversion"
    assert makefile =~ "-Walloc-size-larger-than=1048576"
    assert makefile =~ "-Werror=vla"
    assert makefile =~ "-Wno-unused-parameter"
    assert makefile =~ "$(CC) $(CFLAGS) -shared -o $@ $< $(LDFLAGS)"
  end
end
