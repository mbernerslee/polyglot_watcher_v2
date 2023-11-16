{
  description = "A software development tool to trigger test runs on file save ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pname = "polyglot_watcher_v2";
      version = "0.1.0";

      pkgs = import nixpkgs {inherit system;};
      beamPackages = pkgs.beam.packages.erlang_25;
      elixir = beamPackages.elixir_1_14;
      hex = beamPackages.hex;
    in {
      # `nix develop`.
      devShells = {
        default = pkgs.mkShell {
          packages = [
            elixir
            pkgs.fswatch
          ];
        };
      };
      # `nix fmt`.
      formatter = pkgs.alejandra;
      # `nix build`.
      packages = {
        polyglot-watcher-v2 = pkgs.stdenvNoCC.mkDerivation {
          inherit pname version;
          src = pkgs.nix-gitignore.gitignoreSource [] ./.;
          nativeBuildInputs = [elixir pkgs.makeWrapper];
          buildPhase = ''
            # Expose Nix's hex to Mix.
            export MIX_PATH="${hex}/lib/erlang/lib/hex/ebin"
            export HOME=$PWD/.hex
            mkdir -p $HOME
            mix deps.get
            env MIX_ENV=prod mix escript.build
          '';
          installPhase = ''
            mkdir -p $out/bin
            cp ${pname} $out/bin/${pname}
            wrapProgram $out/bin/${pname} \
              --prefix PATH : ${pkgs.lib.makeBinPath [beamPackages.erlang pkgs.fswatch]}
          '';
        };
        default = self.packages.${system}.polyglot-watcher-v2;
      };
    });
}
