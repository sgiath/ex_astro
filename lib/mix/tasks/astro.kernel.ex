defmodule Mix.Tasks.Astro.Kernels do
  @shortdoc "Downloads kernels for SPICE framework"

  @moduledoc """
  Download some general SPICE kernels to the priv/kernels/ directory

  If you want to download more kernels manually look here:
  https://naif.jpl.nasa.gov/pub/naif/generic_kernels/
  """

  use Mix.Task

  @requirements ["app.start"]

  @base_url "https://naif.jpl.nasa.gov/pub/naif/generic_kernels"

  @asteroids [
    "/spk/asteroids/codes_300ast_20100725.bsp"
  ]

  @comets [
    "/spk/comets/c2013a1_s105_merged.bsp"
  ]

  @lagrange_points [
    "/spk/lagrange_point/L1_de431.bsp",
    "/spk/lagrange_point/L2_de431.bsp",
    "/spk/lagrange_point/L4_de431.bsp",
    "/spk/lagrange_point/L5_de431.bsp"
  ]

  @planets [
    # Mars satellites
    "/spk/satellites/mar097.bsp",

    # Jupiter satellites
    "/spk/satellites/jup344.bsp",
    "/spk/satellites/jup346.bsp",
    "/spk/satellites/jup365.bsp",

    # Saturn satellites
    "/spk/satellites/sat393_daphnis.bsp",
    "/spk/satellites/sat415.bsp",
    "/spk/satellites/sat441.bsp",
    "/spk/satellites/sat452.bsp",
    "/spk/satellites/sat453.bsp",

    # Uranus satellites
    "/spk/satellites/ura111.bsp",
    "/spk/satellites/ura115.bsp",
    "/spk/satellites/ura116.bsp",

    # Neptune satellites
    "/spk/satellites/nep095.bsp",
    "/spk/satellites/nep097.bsp",
    "/spk/satellites/nep102.bsp",

    # Pluto satellites
    "/spk/satellites/plu058.bsp",

    # most up-to-date planets
    "/spk/planets/de440.bsp"
  ]

  @spk_kernels @comets ++ @asteroids ++ @lagrange_points ++ @planets

  @lsk_kernels [
    "/lsk/naif0012.tls",
    "/lsk/latest_leapseconds.tls"
  ]

  @pck_kernels [
    "/pck/pck00011.tpc",
    "/pck/mars_iau2000_v1.tpc",
    "/pck/gm_de440.tpc",
    "/pck/moon_pa_de440_200625.bpc",
    "/pck/earth_latest_high_prec.bpc"
  ]

  @kernels @spk_kernels ++ @lsk_kernels ++ @pck_kernels

  @impl Mix.Task
  def run(_args) do
    File.mkdir_p("priv/kernels/spk/asteroids/")
    File.mkdir_p("priv/kernels/spk/comets/")
    File.mkdir_p("priv/kernels/spk/lagrange_point/")
    File.mkdir_p("priv/kernels/spk/satellites/")
    File.mkdir_p("priv/kernels/spk/planets/")
    File.mkdir_p("priv/kernels/lsk/")
    File.mkdir_p("priv/kernels/pck/")

    Enum.each(@kernels, fn path ->
      if File.exists?("priv/kernels#{path}") do
        IO.puts("File #{path} exists. Skipping")
      else
        IO.puts("\nDownloading #{path} ...")
        download(path)
        IO.puts("File #{path} downloaded\n")
      end
    end)

    IO.puts("""


    #{IO.ANSI.green_background()}All kernels downloaded, now you can put this in your config.exs:#{IO.ANSI.reset()}

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
        "priv/kernels/pck/mars_iau2000_v1.tpc",
        "priv/kernels/pck/gm_de440.tpc",
        "priv/kernels/pck/moon_pa_de440_200625.bpc",
        "priv/kernels/pck/earth_latest_high_prec.bpc"
      ]
    """)
  end

  defp download(path) do
    file = Req.request!(url: @base_url <> path).body

    File.write("priv/kernels#{path}", file)
  end
end
