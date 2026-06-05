{
  description = "Greeter for the COSMIC desktop environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    parts.url = "github:hercules-ci/flake-parts";
    parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    crane.url = "github:ipetkov/crane";

    rust.url = "github:oxalica/rust-overlay";
    rust.inputs.nixpkgs.follows = "nixpkgs";

    nix-filter.url = "github:numtide/nix-filter";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      parts,
      crane,
      rust,
      nix-filter,
      ...
    }:
    parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-linux"
        "x86_64-linux"
      ];

      perSystem =
        {
          self',
          lib,
          system,
          ...
        }:
        let
          pkgs = nixpkgs.legacyPackages.${system}.extend rust.overlays.default;
          rust-toolchain = pkgs.rust-bin.fromRustupToolchainFile ./rust-toolchain.toml;
          craneLib = (crane.mkLib pkgs).overrideToolchain rust-toolchain;
          craneArgs = {
            pname = "cosmic-greeter";
            version = self.rev or "dirty";

            src = nix-filter.lib.filter {
              root = ./.;
              include = [
                ./src
                ./i18n.toml
                ./dbus
                ./Cargo.toml
                ./Cargo.lock
                ./res
                ./cosmic-greeter-config
              ];
            };

            nativeBuildInputs = with pkgs; [
              pkg-config
              rustPlatform.bindgenHook
              just
              cmake
            ];

            buildInputs = with pkgs; [
              cosmic-randr
              libinput
              libxkbcommon
              linux-pam
              udev
              orca
            ];
          };

          cargoArtifacts = craneLib.buildDepsOnly craneArgs;
          cosmic-greeter = craneLib.buildPackage (craneArgs // { inherit cargoArtifacts; });
        in
        {
          apps.cosmic-greeter = {
            type = "app";
            program = lib.getExe self'.packages.default;
          };

          checks.cosmic-greeter = cosmic-greeter;
          packages.default = cosmic-greeter;

          devShells.default = craneLib.devShell {
            # include build inputs
            inputsFrom = [ cosmic-greeter ];
          };
        };
    };
}