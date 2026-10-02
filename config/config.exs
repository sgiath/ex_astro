import Config

# Load order matters: SPICE gives later kernels priority where coverage
# overlaps. Keep it in sync with Mix.Tasks.Astro.Kernels.
config :ex_astro,
  spice_kernels: [
    # comets
    "priv/kernels/spk/comets/c2013a1_s105_merged.bsp",

    # asteroids
    "priv/kernels/spk/asteroids/codes_300ast_20100725.bsp",

    # lagrange points
    "priv/kernels/spk/lagrange_point/L1_de441.bsp",
    "priv/kernels/spk/lagrange_point/L2_de441.bsp",
    "priv/kernels/spk/lagrange_point/L4_de441.bsp",
    "priv/kernels/spk/lagrange_point/L5_de441.bsp",

    # Mars satellites
    "priv/kernels/spk/satellites/mar099.bsp",

    # Jupiter satellites
    "priv/kernels/spk/satellites/jup347.bsp",
    "priv/kernels/spk/satellites/jup348.bsp",
    "priv/kernels/spk/satellites/jup349.bsp",
    "priv/kernels/spk/satellites/jup365.bsp",

    # Saturn satellites
    "priv/kernels/spk/satellites/sat393_daphnis.bsp",
    "priv/kernels/spk/satellites/sat415.bsp",
    "priv/kernels/spk/satellites/sat441.bsp",
    "priv/kernels/spk/satellites/sat455.bsp",
    "priv/kernels/spk/satellites/sat456.bsp",
    "priv/kernels/spk/satellites/sat457.bsp",
    "priv/kernels/spk/satellites/sat459.bsp",
    "priv/kernels/spk/satellites/sat480.bsp",

    # Uranus satellites
    "priv/kernels/spk/satellites/ura184_part-1.bsp",
    "priv/kernels/spk/satellites/ura184_part-2.bsp",
    "priv/kernels/spk/satellites/ura184_part-3.bsp",

    # Neptune satellites
    "priv/kernels/spk/satellites/nep097.bsp",
    "priv/kernels/spk/satellites/nep105.bsp",
    "priv/kernels/spk/satellites/nep104.bsp",
    "priv/kernels/spk/satellites/nep098_part-1.bsp",
    "priv/kernels/spk/satellites/nep098_part-2.bsp",
    "priv/kernels/spk/satellites/nep098_part-3.bsp",

    # Pluto satellites
    "priv/kernels/spk/satellites/plu060.bsp",

    # planets
    "priv/kernels/spk/planets/de442.bsp",

    # leap seconds
    "priv/kernels/lsk/naif0012.tls",
    "priv/kernels/lsk/latest_leapseconds.tls",

    # Planetary Constants Kernels
    "priv/kernels/pck/pck00011.tpc",
    "test/fixtures/kernels/ex_astro_test_many_values.tpc",
    "priv/kernels/pck/mars_iau2000_v1.tpc",
    "priv/kernels/pck/gm_de440.tpc",
    "priv/kernels/pck/moon_pa_de440_200625.bpc",
    "priv/kernels/pck/earth_latest_high_prec.bpc"
  ]
