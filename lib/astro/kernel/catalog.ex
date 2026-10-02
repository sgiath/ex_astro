defmodule Astro.Kernel.Catalog do
  @moduledoc """
  The default set of NAIF generic kernels that `mix astro.kernels` downloads.

  `paths/0` lists the kernels relative to a kernel root (`priv/kernels/` for
  the mix task) in the order they should be loaded, `url/1` gives the NAIF
  download URL of each path, `check_id_word/2` tells a real kernel from, for
  example, an HTML error page saved under a kernel's name, and
  `check_sha256/2` verifies a download against the SHA-256 pinned for it.

  The catalog changes between ex_astro releases as NAIF publishes newer
  solutions and retires old ones. Projects that need a stable kernel set
  should list their kernels explicitly in `config :ex_astro, :spice_kernels`
  instead of deriving that list from `paths/0` at runtime.
  """

  @base_url "https://naif.jpl.nasa.gov/pub/naif/generic_kernels"

  # SPICE gives the most recently loaded kernel priority where coverage
  # overlaps, so this list is ordered for loading: within a planetary system
  # the long-span older solutions come first and the newest solution last, and
  # the planetary ephemeris follows every satellite SPK so its Sun, Earth and
  # barycenter data win over the copies merged into the satellite files.
  @paths [
    # comets
    "spk/comets/c2013a1_s105_merged.bsp",

    # asteroids
    "spk/asteroids/codes_300ast_20100725.bsp",

    # lagrange points
    "spk/lagrange_point/L1_de441.bsp",
    "spk/lagrange_point/L2_de441.bsp",
    "spk/lagrange_point/L4_de441.bsp",
    "spk/lagrange_point/L5_de441.bsp",

    # Mars satellites
    "spk/satellites/mar099.bsp",

    # Jupiter satellites
    "spk/satellites/jup347.bsp",
    "spk/satellites/jup348.bsp",
    "spk/satellites/jup349.bsp",
    "spk/satellites/jup365.bsp",

    # Saturn satellites
    "spk/satellites/sat393_daphnis.bsp",
    "spk/satellites/sat415.bsp",
    "spk/satellites/sat441.bsp",
    "spk/satellites/sat455.bsp",
    "spk/satellites/sat456.bsp",
    "spk/satellites/sat457.bsp",
    "spk/satellites/sat459.bsp",
    "spk/satellites/sat480.bsp",

    # Uranus satellites
    "spk/satellites/ura184_part-1.bsp",
    "spk/satellites/ura184_part-2.bsp",
    "spk/satellites/ura184_part-3.bsp",

    # Neptune satellites
    "spk/satellites/nep097.bsp",
    "spk/satellites/nep105.bsp",
    "spk/satellites/nep104.bsp",
    "spk/satellites/nep098_part-1.bsp",
    "spk/satellites/nep098_part-2.bsp",
    "spk/satellites/nep098_part-3.bsp",

    # Pluto satellites
    "spk/satellites/plu060.bsp",

    # most up-to-date planets
    "spk/planets/de442.bsp",

    # leap seconds
    "lsk/naif0012.tls",
    "lsk/latest_leapseconds.tls",

    # Planetary Constants Kernels
    "pck/pck00011.tpc",
    "pck/mars_iau2000_v1.tpc",
    "pck/gm_de440.tpc",
    "pck/moon_pa_de440_200625.bpc",
    "pck/earth_latest_high_prec.bpc",

    # Frame Kernels
    # MOON_PA/MOON_ME frames for moon_pa_de440_200625.bpc
    "fk/satellites/moon_de440_250416.tf",

    # names for satellite and asteroid IDs not built into CSPICE N0067
    "fk/satellites/jup347_nameid.tf",
    "fk/satellites/jup348_nameid.tf",
    "fk/satellites/jup349_nameid.tf",
    "fk/satellites/sat455_nameid.tf",
    "fk/satellites/sat456_nameid.tf",
    "fk/satellites/sat457_nameid.tf",
    "fk/satellites/sat459_nameid.tf",
    "fk/satellites/sat480_nameid.tf",
    "fk/satellites/ura117_nameid.tf",
    "fk/satellites/nep098_nameid.tf",
    "fk/satellites/nep104_nameid.tf",
    "spk/asteroids/codes_300ast_20100725.tf"
  ]

  # NAIF regenerates these in place under the same name (the Earth PCK about
  # twice a week, extending measured Earth orientation and its prediction),
  # so a downloader should fetch them again on every run.
  @refreshed ["pck/earth_latest_high_prec.bpc"]

  # NAIF replaces the content of these under the same name, so no digest can
  # be pinned for them.
  # FIXME: downloads of these kernels are validated only by their ID word, so
  # a tampered copy that keeps a valid ID word is not detected.
  @unpinned @refreshed ++ ["lsk/latest_leapseconds.tls"]

  # SHA-256 of every immutable kernel. The spk/planets, spk/satellites, and
  # spk/lagrange_point digests were taken from files whose MD5 matched NAIF's
  # aa_checksums.txt in the same directory; NAIF publishes no checksums for the
  # other directories.
  @sha256 %{
    "fk/satellites/jup347_nameid.tf" => "1303dfccf7d758965c698fbcf0c110b41f73da67639fe63f0724de414f559228",
    "fk/satellites/jup348_nameid.tf" => "c80fa162869789639123225024831d21c611380771aba3fffdd368c07b2c5e79",
    "fk/satellites/jup349_nameid.tf" => "03ea700f2b05391e9cec4f41117ed6ca8b4b08c8856abb49c09e8aa88648eba7",
    "fk/satellites/moon_de440_250416.tf" => "a47c71e9c9f33796bdafb2c9d69a7ee447b6016ecad80f71cd6f3e479f9cf768",
    "fk/satellites/nep098_nameid.tf" => "c61ecda345d23c5b4b6e0252504e5c59e6debc21fb65774c7dc77c6a71b27f57",
    "fk/satellites/nep104_nameid.tf" => "bcd74bd7c791b8d368953b794e8f76806784c1da5bbb22550700ce5b0f624d59",
    "fk/satellites/sat455_nameid.tf" => "dc435939e80a35ff467764343a38d6588bd8f2620b6d07d41943ae2e38dd9003",
    "fk/satellites/sat456_nameid.tf" => "57bcb7caa96085938324bca1f5f8996e0ca7e9510b348fc65b897b889b55e6e8",
    "fk/satellites/sat457_nameid.tf" => "9e6edc2d9f38b8e137fef020a168db532c878a289b81500711cf3e1d0bf568e2",
    "fk/satellites/sat459_nameid.tf" => "e0fc8ba2a487b0d83bf5685411005f29b1bd6c9760c783377eebf042b6888c6e",
    "fk/satellites/sat480_nameid.tf" => "c1c20ff442f69ad1663511b9e447e87627484acd1b27fa0ccae82c747af28acd",
    "fk/satellites/ura117_nameid.tf" => "686d4b7acee62bf167d8c6d178c57159c73923654e582cb6d1f1fb1e220f65f1",
    "lsk/naif0012.tls" => "678e32bdb5a744117a467cd9601cd6b373f0e9bc9bbde1371d5eee39600a039b",
    "pck/gm_de440.tpc" => "924ddf4fb9ead9fe8a1aa55780bcabde40b09d00065d58226e24b68d8092f140",
    "pck/mars_iau2000_v1.tpc" => "07ba38b939ae92c085882752a523addd749fde0abb7a3468423099ed02bb3949",
    "pck/moon_pa_de440_200625.bpc" => "60cd55aa401ea2ea97360636f567554bfe4e37bb829f901b4460a455dfaf783f",
    "pck/pck00011.tpc" => "3dff7b1dbeceaa01f25467767d3fa25816051c85d162d1edf04acb310ee28bb1",
    "spk/asteroids/codes_300ast_20100725.bsp" => "7bb92faaadac29ec0b62aa96041a37c92ae24b9a5460de03d3fcaa2f63fe51f0",
    "spk/asteroids/codes_300ast_20100725.tf" => "15ee3b1731817774672725ccc226b249eb9ca5aa5d0a6a7805c91e5f57497f40",
    "spk/comets/c2013a1_s105_merged.bsp" => "0e858f2f393b426b1dfb02e6178bfb3fe63824c52a4900bca5f6ef518316f5a2",
    "spk/lagrange_point/L1_de441.bsp" => "ec1931712072b71d34641a925324f7a05b7bf0c7f171cc79eea33e355ba47925",
    "spk/lagrange_point/L2_de441.bsp" => "a68f08f85cd243d87415fab1be3e07e9e2feb3cc17dc380c5603cc79ecb6183e",
    "spk/lagrange_point/L4_de441.bsp" => "4292c90f0ba0e4764f38646e76cf13d3ebc56281559ef312dfb75bf6a8bcf6ac",
    "spk/lagrange_point/L5_de441.bsp" => "2f30be734f2df2ca8290768b005d73f6be1b160982941c997a15e2d3de0c1393",
    "spk/planets/de442.bsp" => "8d5001fab315eeff222cc51f7cf7ffcdb43fb38fb9ac73ff09e09a5b361fd388",
    "spk/satellites/jup347.bsp" => "b68bd0af2797aaebe1df0885672e116ad1627e45564212c2ac42a53907e8142e",
    "spk/satellites/jup348.bsp" => "9b04592fb6d5448eba480c347b60ed5f0629d049e59417c40039021b64662701",
    "spk/satellites/jup349.bsp" => "a8f682fd0f156db47ee9672e0276f0842eb70d3ade8533fed59e38b6d5032971",
    "spk/satellites/jup365.bsp" => "dbf016c01ba4d022154838000cf3f06962cf958ddc503a366f7fe8f81495c5cb",
    "spk/satellites/mar099.bsp" => "9991e57b196bae1a096acc6e2afc6718102ee420d684695de0f0333064c046bc",
    "spk/satellites/nep097.bsp" => "5c1132fdc48c54e5d2e4eb663e1ed1a876911eae9433c203f29a5a1b5e1fa9b1",
    "spk/satellites/nep098_part-1.bsp" => "5327f47abba438d993237ff676ab03b728778a965bb238f86de883c0ad7790b8",
    "spk/satellites/nep098_part-2.bsp" => "7f1ddadea0661822d47e41b8086f45720aa40900567bdcd565e65c14d62db52e",
    "spk/satellites/nep098_part-3.bsp" => "16955f87878e41b16934e697213350bc2d6a1b3e04d98f29ba7e0fce328b4355",
    "spk/satellites/nep104.bsp" => "ef1906c0693f30952eb42b8d9640e9a3e4a6aa03cd899ffd94f7c3e8e1f6c8a0",
    "spk/satellites/nep105.bsp" => "be2ea8cd16658c957e803c7896731c81ad1a8afe2caca6fbf87d7b68bc4392c7",
    "spk/satellites/plu060.bsp" => "dfbb102491a26ed41ae08ca3f8963f22f0219df1d8f265ab87b9ad825a826fc6",
    "spk/satellites/sat393_daphnis.bsp" => "8b21b3b68e5603006b67cb02197d789afa2e04925c3495363ac16fe180be2e08",
    "spk/satellites/sat415.bsp" => "5bc92ff62953ce4ab460a1816024dda3f560112aed6c76b181e19bfa7307d909",
    "spk/satellites/sat441.bsp" => "d7e444a9ba7a52b8f448ff0747030789524d2f0c1212e4e2bd7f5fc3c96444d5",
    "spk/satellites/sat455.bsp" => "c2269e9b18c70a7a66219e1209cde73c90e328864b1204598ecea8ae9115c672",
    "spk/satellites/sat456.bsp" => "55ea388b1e60e0a8f11fdc12e53a245d653e3f1cbf6f7886209c7d5281f6f811",
    "spk/satellites/sat457.bsp" => "f3d6fb99441032f5fae8cdceec37a57455abb09efd94a4235b4b068d7faafc24",
    "spk/satellites/sat459.bsp" => "cd9404b7904f1275af857b5d460cb63548eba37e92ad668b7f0b1108a78ca2c2",
    "spk/satellites/sat480.bsp" => "12d2cfd8da371883bd4edbd67c31fafa98ca7779a09da6819e29d53cdc6daf32",
    "spk/satellites/ura184_part-1.bsp" => "6f4cc44f49d56202f93a0fcb5d0dc1422f4c897e095172256a494eb837fd7b7c",
    "spk/satellites/ura184_part-2.bsp" => "2bf29a0ca886324b6eadab3b248b5fd5db6971090903587f774dcc75cbca0225",
    "spk/satellites/ura184_part-3.bsp" => "273cd4ccc470d1098562cd4e94fa48fc2b4c6b1c2896308e473c949b87937c53"
  }

  # Every SPICE kernel starts with an ID word naming its architecture and
  # type. Checking it keeps an error page served with HTTP 200, or one saved
  # by an older downloader, from being used as a kernel.
  @id_words %{
    ".bsp" => "DAF/SPK ",
    ".bpc" => "DAF/PCK ",
    ".tls" => "KPL/LSK",
    ".tpc" => "KPL/PCK",
    ".tf" => "KPL/FK"
  }

  for path <- @paths, not Map.has_key?(@id_words, Path.extname(path)) do
    raise "no SPICE ID word known for #{path}; add its extension to @id_words"
  end

  for path <- @paths, not Map.has_key?(@sha256, path), path not in @unpinned do
    raise "no SHA-256 pinned for #{path}; add it to @sha256 or, if NAIF changes it in place, to @unpinned"
  end

  @doc """
  Returns the catalog kernel paths relative to the kernel root, in SPICE load
  order.

  SPICE gives later kernels priority where coverage overlaps, so load the
  paths in the returned order: the planetary ephemeris comes after every
  satellite, Lagrange point, comet and asteroid SPK.
  """
  @spec paths() :: [String.t()]
  def paths, do: @paths

  @doc """
  Returns the NAIF download URL of a catalog path.

      iex> Astro.Kernel.Catalog.url("lsk/naif0012.tls")
      "https://naif.jpl.nasa.gov/pub/naif/generic_kernels/lsk/naif0012.tls"
  """
  @spec url(String.t()) :: String.t()
  def url(path), do: "#{@base_url}/#{path}"

  @doc """
  Returns `true` for catalog paths that NAIF regenerates in place, so an
  existing copy goes stale and should be downloaded again.
  """
  @spec refresh?(String.t()) :: boolean()
  def refresh?(path), do: path in @refreshed

  @doc """
  Checks that `file` starts with the SPICE ID word of the kernel type of
  `kernel_path`.

  The extension of `kernel_path`, not of `file`, selects the expected ID word,
  so a partial download such as `de442.bsp.part` can be checked against
  `spk/planets/de442.bsp`. Returns `{:error, message}` when the file is not
  such a kernel (for example an HTML error page) and `{:error, posix}` when it
  cannot be read. Raises `KeyError` if `kernel_path` has an extension that no
  catalog kernel uses.
  """
  @spec check_id_word(Path.t(), Path.t()) :: :ok | {:error, String.t() | File.posix()}
  def check_id_word(file, kernel_path) do
    expected = Map.fetch!(@id_words, Path.extname(kernel_path))

    case File.open(file, [:read, :binary], &IO.binread(&1, byte_size(expected))) do
      {:ok, ^expected} ->
        :ok

      {:ok, data} when is_binary(data) ->
        {:error, "not a SPICE kernel: starts with #{inspect(data)}, expected #{inspect(expected)}"}

      {:ok, :eof} ->
        {:error, "not a SPICE kernel: empty file"}

      {:ok, {:error, reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Checks that `file` has the SHA-256 digest pinned for the catalog path
  `kernel_path`.

  Kernels that NAIF replaces under the same name, `pck/earth_latest_high_prec.bpc`
  and `lsk/latest_leapseconds.tls`, have no pinned digest; for them this
  returns `:ok` without reading the file, so only `check_id_word/2` validates
  them. Returns `{:error, message}` on a digest mismatch and `{:error, posix}`
  when the file cannot be read. Raises `KeyError` if `kernel_path` is not in
  the catalog.
  """
  @spec check_sha256(Path.t(), String.t()) :: :ok | {:error, String.t() | File.posix()}
  def check_sha256(file, kernel_path) do
    if kernel_path in @unpinned do
      :ok
    else
      expected = Map.fetch!(@sha256, kernel_path)

      case File.open(file, [:read, :binary], &sha256_device(&1, :crypto.hash_init(:sha256))) do
        {:ok, {:ok, ^expected}} -> :ok
        {:ok, {:ok, actual}} -> {:error, "SHA-256 mismatch: expected #{expected}, got #{actual}"}
        {:ok, {:error, reason}} -> {:error, reason}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp sha256_device(device, state) do
    case IO.binread(device, 1_048_576) do
      :eof -> {:ok, Base.encode16(:crypto.hash_final(state), case: :lower)}
      {:error, _reason} = error -> error
      data -> sha256_device(device, :crypto.hash_update(state, data))
    end
  end
end
