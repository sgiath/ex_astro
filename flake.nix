{
  description = "Astro Elixir lib wrapping SPICE and ERFA";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    expert.url = "github:expert-lsp/expert";
  };

  outputs =
    { nixpkgs, expert, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      beamPackages = pkgs.beamMinimal29Packages.overrideScope (
        _final: prev: {
          elixir = prev.elixir_1_20;
        }
      );
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          beamPackages.elixir
          git
          liberfa
          prettier

          # tooling
          (expert.packages.${system}.default.override { inherit beamPackages; })
          nixd
          nixfmt
        ];

        env = {
          MIX_OS_DEPS_COMPILE_PARTITION_COUNT = "16";
          ERL_AFLAGS = "+pc unicode -kernel shell_history enabled";
          ELIXIR_ERL_OPTIONS = "+fnu +sssdio 128";
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.liberfa ];
        };
      };
    };
}
