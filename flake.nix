{
  description = "basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gleam2nix.url = "github:mtoohey31/gleam2nix";
    crane.url = "github:ipetkov/crane";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      gleam2nix,
      crane,
      rust-overlay,
    }:
    {
      overlays = {
        default = nixpkgs.lib.composeManyExtensions [
          gleam2nix.overlays.default
          (import rust-overlay)
        ];
      };
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend self.overlays.default;

        manifest = pkgs.lib.importTOML ./gleam.toml;

        craneLib = crane.mkLib pkgs;

        rustLib = craneLib.buildPackage ({
          src = craneLib.cleanCargoSource ./rslib;

          strictDeps = true;

          buildInputs =
            [ ]
            ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.libiconv
            ];
        });

        default =
          (pkgs.buildGleamProgram {
            src = builtins.path {
              path = ./.;
              name = "${manifest.name}-src";
            };
          }).overrideAttrs
            (oldAttrs: {
              buildInputs = (oldAttrs.buildInputs or [ ]) ++ [ rustLib ];

              postInstall = ''
                mkdir -p $out/priv
                cp ${rustLib}/lib/librslib.so $out/priv/

                mv $out/bin/${manifest.name} $out/bin/${manifest.name}_unwrapped
                makeWrapper $out/bin/${manifest.name}_unwrapped \
                    $out/bin/${manifest.name} \
                    --chdir $out
              '';
            });
      in
      {
        checks = {
          inherit rustLib;
          inherit default;
        };

        packages.default = default;

        devShells.default = craneLib.devShell {
          inputsFrom = [ default ];
        };
      }
    );
}
