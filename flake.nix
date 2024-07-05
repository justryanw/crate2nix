{
  description = "Rust-Nix";

  nixConfig = {
    extra-trusted-public-keys = "justryanw.cachix.org-1:oan1YuatPBqGNFEflzCmB+iwLPtzq1S1LivN3hUzu60=";
    extra-substituters = "https://justryanw.cachix.org";
    allow-import-from-derivation = true;
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };

    rust-overlay.url = "github:oxalica/rust-overlay";

    crate2nix.url = "github:nix-community/crate2nix";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { flake-parts, crate2nix, ... }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [
      "x86_64-linux"
      "aarch64-linux"
      "x86_64-darwin"
      "aarch64-darwin"
    ];

    imports = [
      ./nix/rust-overlay/flake-module.nix
      ./nix/devshell/flake-module.nix
    ];

    perSystem = { system, pkgs, ... }:
      let
        # If you dislike IFD, you can also generate it with `crate2nix generate` 
        # on each dependency change and import it here with `import ./Cargo.nix`.
        # cargoNix = inputs.crate2nix.tools.${system}.appliedCargoNix {
        #   name = "rustnix";
        #   src = ./.;
        # };

        cargoNix = pkgs.callPackage (crate2nix.tools.${system}.generatedCargoNix {
          name = "rustnix";
          src = ./.;
        }) {
          defaultCrateOverrides = pkgs.defaultCrateOverrides;
        };
      in
      rec {
        checks = {
          rustnix = cargoNix.rootCrate.build.override {
            runTests = true;
          };
        };

        packages = {
          rustnix = cargoNix.rootCrate.build;
          default = packages.rustnix;

          inherit (pkgs) rust-toolchain;

          rust-toolchain-versions = pkgs.writeScriptBin "rust-toolchain-versions" ''
            ${pkgs.rust-toolchain}/bin/cargo --version
            ${pkgs.rust-toolchain}/bin/rustc --version
          '';
        };
      };
  };
}
