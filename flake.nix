  {
  description = "Elixir polyglot watcher development";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Elixir toolchain
            elixir
            erlang

            # Unix tools your script needs
            bash
            bc
            python3
            inotify-tools
          ];

          #shellHook = ''
          #  echo "Elixir dev environment loaded!"
          #  echo "Elixir: $(elixir --version | head -1)"
          #'';
        };
      });
  }
