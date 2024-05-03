{
  description = "Tidy tree layouts.";

  inputs = {
    hacknix.url = "github:hackworthltd/hacknix";
    nixpkgs.follows = "hacknix/nixpkgs";

    flake-parts.url = "github:hercules-ci/flake-parts";

    systems.url = "github:nix-systems/default";

    gitignore.url = "github:hercules-ci/gitignore.nix";
    gitignore.inputs.nixpkgs.follows = "nixpkgs";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;

    pre-commit-hooks-nix.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";

    crane.url = "github:ipetkov/crane";
    crane.inputs.nixpkgs.follows = "nixpkgs";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";

    advisory-db.url = "github:rustsec/advisory-db";
    advisory-db.flake = false;
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      imports = [
        inputs.treefmt-nix.flakeModule
        inputs.pre-commit-hooks-nix.flakeModule
      ];
      perSystem = { config, self', pkgs, lib, system, ... }:
        let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.hacknix.overlays.default
              inputs.rust-overlay.overlays.default
            ];
          };

          rustToolchain =
            (pkgs.rust-bin.fromRustupToolchainFile (./rust-toolchain.toml)).override {
              extensions = [
                "rust-src"
                "rust-analyzer"
                "clippy"
              ];
            };

          rustWasmToolchain = rustToolchain.override {
            targets = [ "wasm32-unknown-unknown" ];
          };

          pname = "tidyt-workspace";

          npm-scope = "hackworthltd";

          cargoToml = builtins.fromTOML (builtins.readFile ./Cargo.toml);
          cargoLock = builtins.fromTOML (builtins.readFile ./Cargo.lock);

          wasm-bindgen-cli =
            let
              wasmBindgenCargoVersions = builtins.map ({ version, ... }: version) (builtins.filter ({ name, ... }: name == "wasm-bindgen") cargoLock.package);
              wasmBindgenVersion = assert builtins.length wasmBindgenCargoVersions == 1; builtins.elemAt wasmBindgenCargoVersions 0;
            in
            pkgs.wasm-bindgen-cli.override {
              version = wasmBindgenVersion;
              hash = "sha256-1VwY8vQy7soKEgbki4LD+v259751kKxSxmo/gqE6yV0=";
              cargoHash = "sha256-aACJ+lYNEU8FFBs158G1/JG8sc6Rq080PeKCMnwdpH0=";
            };

          inherit (cargoToml.workspace.package) version;

          craneLib = (inputs.crane.mkLib pkgs).overrideToolchain rustToolchain;
          craneLibWasm = (inputs.crane.mkLib pkgs).overrideToolchain rustWasmToolchain;

          src = craneLib.cleanCargoSource (craneLib.path ./.);

          cargoExtraArgs = "--frozen --offline";

          commonArgs = {
            inherit pname version src cargoExtraArgs;
            strictDeps = true;

            buildInputs = [
            ] ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
              pkgs.libiconv
            ];
          };

          cargoArtifacts = craneLib.buildDepsOnly commonArgs;

          individualCrateArgs = commonArgs // {
            inherit cargoArtifacts;
            doCheck = false;
          };

          wasmArgs = commonArgs // {
            CARGO_BUILD_TARGET = "wasm32-unknown-unknown";
          };

          cargoArtifactsWasm = craneLibWasm.buildDepsOnly wasmArgs;

          individualCrateArgsWasm = wasmArgs // {
            cargoArtifacts = cargoArtifactsWasm;
            doCheck = false;
          };

          # For the moment, it's not possible to run
          # `wasm32-unknown-unknown` benchmarks, so we run them
          # native.
          mkBench = pkgName: crateArgs: (craneLib.mkCargoDerivation (crateArgs // {
            doInstallCargoArtifacts = false;

            # Use `bencher` format so we can use `cargo
            # bench`-compatible tooling.
            buildPhaseCargoCommand = ''
              mkdir -p $out
              cargo bench --bench=${pkgName} --frozen --offline -- --output-format=bencher | tee $out/bench.txt
            '';

            nativeBuildInputs = [
              pkgs.coreutils
              pkgs.gnuplot
            ];
          })).overrideAttrs
            (oldAttrs: {
              requiredSystemFeatures = (oldAttrs.requiredSystemFeatures or [ ]) ++ [ "benchmark" ];
            });

          mkWasmNpmPackage = pkgName: crateArgs: craneLibWasm.mkCargoDerivation (crateArgs // {
            doInstallCargoArtifacts = false;

            buildPhaseCargoCommand = ''
              WASM_PACK_CACHE=.wasm-pack-cache wasm-pack build --out-dir $out/pkg --scope "${npm-scope}" --mode no-install --target bundler --release ${pkgName} --profile release --frozen --offline
            '';

            nativeBuildInputs = [
              pkgs.binaryen
              pkgs.wasm-pack
              wasm-bindgen-cli
            ];
          });

          mkCheck = pkgName: crateArgs: craneLib.mkCargoDerivation (crateArgs // {
            doInstallCargoArtifacts = false;

            buildPhaseCargoCommand = ''
              cargo test --release --profile release --frozen --offline
            '';
          });

          mkWasmCheck = pkgName: crateArgs: craneLibWasm.mkCargoDerivation (crateArgs // {
            doInstallCargoArtifacts = false;

            buildPhaseCargoCommand = ''
              WASM_PACK_CACHE=.wasm-pack-cache wasm-pack test --chrome --headless --mode no-install --release ${pkgName} --profile release --frozen --offline
            '';

            nativeBuildInputs = [
              pkgs.binaryen
              pkgs.wasm-pack
              wasm-bindgen-cli

              # We would prefer to use `geckodriver`, but it hangs on
              # our tests in the Nix sandbox, for some reason.
              pkgs.chromedriver
              pkgs.chromium
            ];
          });

          tidytCrateArgs = baseArgs: pname: baseArgs // {
            inherit pname;
            cargoExtraArgs = "${cargoExtraArgs} --package tidyt";
            inherit (craneLib.crateNameFromCargoToml { cargoToml = ./tidyt/Cargo.toml; }) version;
          };

          tidytWasmCrateArgs = baseArgs: pname: baseArgs // {
            inherit pname;
            cargoExtraArgs = "${cargoExtraArgs} --package tidyt-wasm";
            inherit (craneLib.crateNameFromCargoToml { cargoToml = ./tidyt-wasm/Cargo.toml; }) version;
          };

          tidyt-crate = craneLib.buildPackage (tidytCrateArgs individualCrateArgs "${pname}-tidyt");

          tidyt-crate-check = mkCheck "tidyt" (tidytCrateArgs individualCrateArgs "${pname}-tidyt-wasm-check");

          tidyt-crate-bench = mkBench "tidyt" (tidytCrateArgs individualCrateArgs "${pname}-tidyt");

          tidyt-wasm-crate = craneLib.buildPackage (tidytWasmCrateArgs individualCrateArgs "${pname}-tidyt-wasm");

          tidyt-wasm-crate-wasm = craneLibWasm.buildPackage (tidytWasmCrateArgs individualCrateArgsWasm "${pname}-tidyt-wasm-wasm");

          #tidyt-wasm-crate-wasm-check = mkWasmCheck "tidyt-wasm" (tidytWasmCrateArgs individualCrateArgsWasm "${pname}-tidyt-wasm-wasm-check");

          tidyt-wasm-crate-wasm-npm = mkWasmNpmPackage "tidyt-wasm" (tidytWasmCrateArgs individualCrateArgsWasm "${pname}-tidyt-wasm-wasm-npm");

          #tidyt-wasm-crate-bench = mkBench "tidyt-wasm" (tidytWasmCrateArgs individualCrateArgs "${pname}-tidyt-wasm");

          inputsFrom = [
            config.treefmt.build.devShell
            config.pre-commit.devShell
          ];

          devShellPackages = with pkgs; [
            cargo-watch
            critcmp
            gnuplot
            nil
          ];
        in
        {
          checks = {
            # tidyt-workspace-clippy = craneLib.cargoClippy (commonArgs // {
            #   inherit cargoArtifacts;
            #   cargoClippyExtraArgs = "--all-targets -- --deny warnings";
            # });

            tidyt-workspace-audit = craneLib.cargoAudit {
              inherit (inputs) advisory-db;
              inherit src;
            };
          } // (pkgs.lib.optionalAttrs (system == "x86_64-linux") {
            inherit tidyt-crate-check;
            #inherit tidyt-wasm-crate-wasm-check;
          });

          packages = {
            default = tidyt-wasm-crate-wasm-npm;
            inherit tidyt-crate tidyt-wasm-crate;
            inherit tidyt-wasm-crate-wasm;
            inherit tidyt-wasm-crate-wasm-npm;
          } // (pkgs.lib.optionalAttrs (system == "x86_64-linux") {
            inherit tidyt-crate-bench;
            #inherit tidyt-wasm-crate-bench;
          });

          treefmt.config = {
            projectRootFile = "flake.nix";
            programs = {
              nixpkgs-fmt.enable = true;
              rustfmt.enable = true;
            };
          };

          pre-commit = {
            check.enable = true;
            settings = {
              hooks = {
                treefmt.enable = true;
                actionlint.enable = true;
              };
            };
          };

          devShells.default = craneLib.devShell {
            inherit inputsFrom;
            packages = devShellPackages;
          };

          devShells.wasm = craneLibWasm.devShell {
            inherit inputsFrom;
            packages = devShellPackages ++ (with pkgs; [
              binaryen

              # Prefer `geckodriver` to `chromedriver` for interactive
              # development.
              geckodriver
              nodejs_20
              wasm-pack
            ] ++ [
              wasm-bindgen-cli
            ]);
          };
        };

      flake =
        let
          pkgs = import inputs.nixpkgs
            {
              system = "x86_64-linux";
              overlays = [
                inputs.hacknix.overlays.default
                inputs.rust-overlay.overlays.default
              ];
            };
        in
        {
          hydraJobs = {
            inherit (inputs.self) checks;
            inherit (inputs.self) packages;
            inherit (inputs.self) devShells;

            required = pkgs.releaseTools.aggregate {
              name = "required-nix-ci";
              constituents = builtins.map builtins.attrValues (with inputs.self.hydraJobs; [
                packages.x86_64-linux
                packages.aarch64-darwin
                checks.x86_64-linux
                checks.aarch64-darwin
              ]);
              meta.description = "Required Nix CI builds";
            };
          };

          ciJobs = pkgs.lib.flakes.recurseIntoHydraJobs inputs.self.hydraJobs;
        };
    };
}
