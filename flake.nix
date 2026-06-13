{
  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{ parts, ... }:
    parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      perSystem =
        { pkgs, ... }:
        let
          beamPackages = pkgs.beam_minimal.packages.erlang_29;
          elixir = beamPackages.elixir_1_20;
        in
        {
          devShells = {
            default = pkgs.mkShell {
              packages = with pkgs; [
                elixir
                liberfa
                gmp
                pkg-config
                prettier
              ];

              env = {
                MIX_OS_DEPS_COMPILE_PARTITION_COUNT = "16";
                ERL_AFLAGS = "+pc unicode -kernel shell_history enabled";
                ELIXIR_ERL_OPTIONS = "+fnu +sssdio 128";
              };

              shellHook = ''
                export LD_LIBRARY_PATH="${
                  pkgs.lib.makeLibraryPath [
                    pkgs.liberfa
                    pkgs.gmp
                  ]
                }:$LD_LIBRARY_PATH"
              '';
            };
          };
        };
    };
}
