ExUnit.start()

# Tests tagged :kernels read these catalog kernels from priv/kernels/; the
# other tests only need the fixtures in test/fixtures/. `mix test` applies
# command-line filters such as `--exclude kernels` before loading this file.
kernels = [
  "lsk/naif0012.tls",
  "lsk/latest_leapseconds.tls",
  "pck/pck00011.tpc",
  "pck/gm_de440.tpc",
  "spk/planets/de442.bsp"
]

kernels_excluded? =
  Enum.any?(ExUnit.configuration()[:exclude], fn filter -> filter == :kernels or match?({:kernels, _value}, filter) end)

missing = Enum.reject(kernels, &File.regular?(Path.join("priv/kernels", &1)))

if missing != [] and not kernels_excluded? do
  Mix.raise("""
  Tests tagged :kernels need these SPICE kernels, missing from priv/kernels/:

  #{Enum.map_join(missing, "\n", &"  #{&1}")}

  Download them with `mix astro.kernels`, or run only the fixture-based tests
  with `mix test --exclude kernels`.
  """)
end
