import Config

config :ex_astro,
  spice_kernels: [
    # asteroids
    "priv/kernels/spk/asteroids/codes_300ast_20100725.bsp",

    # comets
    "priv/kernels/spk/comets/c2013a1_s105_merged.bsp",

    # lagrange points
    "priv/kernels/spk/lagrange_point/L1_de431.bsp",
    "priv/kernels/spk/lagrange_point/L2_de431.bsp",
    "priv/kernels/spk/lagrange_point/L4_de431.bsp",
    "priv/kernels/spk/lagrange_point/L5_de431.bsp",

    # Mars satellites
    "priv/kernels/spk/satellites/mar097.bsp",

    # Jupiter satellites
    "priv/kernels/spk/satellites/jup344.bsp",
    "priv/kernels/spk/satellites/jup346.bsp",
    "priv/kernels/spk/satellites/jup365.bsp",

    # Saturn satellites
    "priv/kernels/spk/satellites/sat393_daphnis.bsp",
    "priv/kernels/spk/satellites/sat415.bsp",
    "priv/kernels/spk/satellites/sat441.bsp",
    "priv/kernels/spk/satellites/sat452.bsp",
    "priv/kernels/spk/satellites/sat453.bsp",

    # Uranus satellites
    "priv/kernels/spk/satellites/ura111.bsp",
    "priv/kernels/spk/satellites/ura115.bsp",
    "priv/kernels/spk/satellites/ura116.bsp",

    # Neptune satellites
    "priv/kernels/spk/satellites/nep095.bsp",
    "priv/kernels/spk/satellites/nep097.bsp",
    "priv/kernels/spk/satellites/nep102.bsp",

    # Pluto satellites
    "priv/kernels/spk/satellites/plu058.bsp",

    # planets
    "priv/kernels/spk/planets/de440.bsp",

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
