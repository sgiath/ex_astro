import Config

# Mix evaluates this file after compiling the project, so the catalog module
# is available. The fixture defines its own body, so its position in the load
# order does not matter.
config :ex_astro,
  spice_kernels:
    Enum.map(Astro.Kernel.Catalog.paths(), &Path.join("priv/kernels", &1)) ++
      ["test/fixtures/kernels/ex_astro_test_many_values.tpc"]
