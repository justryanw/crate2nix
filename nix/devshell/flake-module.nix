{ inputs, lib, ... }: {
  imports = [
    inputs.devshell.flakeModule
  ];

  config.perSystem =
    { pkgs
    , ...
    }: {
      config.devshells.default = {
        imports = [
          "${inputs.devshell}/extra/language/c.nix"
        ];

        commands = with pkgs; [
          { package = rust-toolchain; category = "rust"; }
          { package = (writeShellScriptBin "cache" ''
            echo "Caching inputs"
            nix flake archive --json $1 | ${jq}/bin/jq -r '.path,(.inputs|to_entries[].value.path)' | cachix push justryanw
            echo "Caching runtime closure"
            nix build --json $1 | ${jq}/bin/jq -r '.[].outputs | to_entries[].value' | cachix push justryanw;
          ''); }
        ];

        language.c = {
          libraries = lib.optional pkgs.stdenv.isDarwin pkgs.libiconv;
        };

        env = [
          { name = "RUST_SRC_PATH"; value = "${pkgs.rustPlatform.rustLibSrc}"; }
        ];
      };
    };
}
