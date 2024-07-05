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
    ];

    perSystem = { system, pkgs, ... }:
      let
        name = "rustnix";

        buildInputs = (with pkgs; [
          libxkbcommon
          alsa-lib
          udev
          vulkan-loader
          wayland
        ] ++ (with xorg; [
          libXcursor
          libXrandr
          libXi
          libX11
        ]));

        cargoNix = pkgs.callPackage
          (crate2nix.tools.${system}.generatedCargoNix {
            inherit name;
            src = ./.;
          })
          {
            defaultCrateOverrides = pkgs.defaultCrateOverrides // {
              ${name} = attrs: {
                nativeBuildInputs = [ pkgs.makeWrapper ];

                postInstall = ''
                  wrapProgram $out/bin/${name} \
                    --prefix LD_LIBRARY_PATH : ${pkgs.lib.makeLibraryPath buildInputs}
                  mkdir -p $out/bin/assets
                  cp -a assets $out/bin
                '';
              };
            };
          };
      in
      rec {
        packages = {
          rustnix = cargoNix.rootCrate.build;
          default = packages.rustnix;

          inherit (pkgs) rust-toolchain;

          rust-toolchain-versions = pkgs.writeScriptBin "rust-toolchain-versions" ''
            ${pkgs.rust-toolchain}/bin/cargo --version
            ${pkgs.rust-toolchain}/bin/rustc --version
          '';
        };

        devShells.default = pkgs.mkShell {
          inherit buildInputs;

          nativeBuildInputs = with pkgs; [
            rust-toolchain
            pkg-config
          ];

          RUST_SRC_PATH = "${pkgs.rustPlatform.rustLibSrc}";
          LD_LIBRARY_PATH = "${pkgs.lib.makeLibraryPath buildInputs}";
        };
      };
  };
}
