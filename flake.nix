{
  description = "pix2 - NixOS host for Piclaw";

  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixos-25.11&shallow=1";
    nixpkgs-unstable.url = "git+https://github.com/NixOS/nixpkgs.git?ref=nixpkgs-unstable&shallow=1";
    kernel-nixpkgs.url = "git+https://github.com/NixOS/nixpkgs.git?ref=master&shallow=1";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    codex-cli = {
      url = "github:sadjow/codex-cli-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      disko,
      sops-nix,
      claude-code,
      codex-cli,
      rust-overlay,
      llm-agents,
      ...
    }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkPkgs =
        system:
        let
          unstablePkgs = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
          hostOverlay = final: _prev: {
            agent-browser = llm-agents.packages.${final.stdenv.hostPlatform.system}.agent-browser;
            agentmemory = final.callPackage ./pkgs/agentmemory { };
            amp-code = final.callPackage ./pkgs/amp.nix { };
            camofox-browser = final.callPackage ./pkgs/camofox-browser { };
            claude-code-acp = final.callPackage ./pkgs/claude-code-acp { };
            cli-proxy-api = final.callPackage ./pkgs/cli-proxy-api.nix { };
            codex-acp = final.callPackage ./pkgs/codex-acp.nix { };
            cursor-cli = final.callPackage ./pkgs/cursor-cli.nix { };
            droid = final.callPackage ./pkgs/droid.nix { };
            gogcli = final.callPackage ./pkgs/gogcli.nix { };
            grok = final.callPackage ./pkgs/grok.nix { };
            iii = final.callPackage ./pkgs/iii.nix { };
            kickbacks-ai = final.callPackage ./pkgs/kickbacks-ai.nix { };
            open-webui =
              let
                version = "0.10.2";
                src = final.fetchFromGitHub {
                  owner = "open-webui";
                  repo = "open-webui";
                  tag = "v${version}";
                  hash = "sha256-tJ9b5up5FoX5TrmpwMWevyA/o3Ai/lKsHu+nahc2Ttc=";
                };
                frontend = unstablePkgs.open-webui.frontend.overrideAttrs (_old: {
                  inherit version src;
                  npmDeps = final.fetchNpmDeps {
                    inherit src;
                    hash = "sha256-yw/1n1jBCUtt8wUqJmIkB3W53wsXTKuAFG/EMwcTpx8=";
                  };
                });
              in
              unstablePkgs.open-webui.overridePythonAttrs (old: {
                inherit version src;
                makeWrapperArgs = [ "--set FRONTEND_BUILD_DIR ${frontend}/share/open-webui" ];
                passthru = (old.passthru or { }) // { inherit frontend; };
              });
            oracle = final.callPackage ./pkgs/oracle.nix { };
            plausible = final.callPackage ./pkgs/plausible.nix { };
            portless = final.callPackage ./pkgs/portless { };
            rust-nightly = final.rust-bin.nightly.latest.default.override {
              extensions = [
                "rust-src"
                "rust-analyzer"
                "llvm-tools"
              ];
            };
            rust-nightly-llvm-tools =
              let
                rustTarget = final.stdenv.hostPlatform.config;
              in
              final.runCommand "rust-nightly-llvm-tools-${final.rust-nightly.version}" { } ''
                mkdir -p "$out/bin"
                for tool in llvm-cov llvm-profdata; do
                  ln -s "${final.rust-nightly}/lib/rustlib/${rustTarget}/bin/$tool" "$out/bin/$tool"
                done
              '';
            sfw = final.callPackage ./pkgs/sfw.nix { };
            signal-cli = final.callPackage ./pkgs/signal-cli.nix { signal-cli = _prev.signal-cli; };
            tirith = final.callPackage ./pkgs/tirith.nix { };
            vet-run = final.callPackage ./pkgs/vet-run.nix { };
            inherit (unstablePkgs)
              bun
              fastfetch
              gdu
              gh
              jujutsu
              mosh
              sysbench
              tmux
              todoist
              uv
              zellij
              ;
            tsshd = final.callPackage ./pkgs/tsshd.nix { tsshd = unstablePkgs.tsshd; };
          };
        in
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [
            claude-code.overlays.default
            codex-cli.overlays.default
            rust-overlay.overlays.default
            hostOverlay
          ];
        };
      mkNixosConfiguration =
        { system, hostModule }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs; };
          modules = [
            { nixpkgs.pkgs = mkPkgs system; }
            disko.nixosModules.disko
            sops-nix.nixosModules.sops
            home-manager.nixosModules.home-manager
            hostModule
          ];
        };
    in
    {
      formatter = forAllSystems (system: (mkPkgs system).nixfmt-rfc-style);

      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          inherit (pkgs)
            agentmemory
            amp-code
            camofox-browser
            claude-code-acp
            cli-proxy-api
            codex-acp
            cursor-cli
            droid
            gogcli
            grok
            iii
            kickbacks-ai
            oracle
            portless
            sfw
            signal-cli
            tirith
            vet-run
            ;
        }
      );

      nixosConfigurations = {
        pix2 = mkNixosConfiguration {
          system = "x86_64-linux";
          hostModule = ./hosts/pix2/default.nix;
        };

        emoji = mkNixosConfiguration {
          system = "x86_64-linux";
          hostModule = ./hosts/emoji/default.nix;
        };
      }
      // nixpkgs.lib.listToAttrs (
        map (
          i:
          nixpkgs.lib.nameValuePair "crawl${toString i}" (mkNixosConfiguration {
            system = "x86_64-linux";
            hostModule = import ./hosts/crawl {
              shardIndex = i;
              # Verified per box over rescue SSH 2026-06-12: crawl0/1 carry NVMe,
              # crawl2-5 SATA SSD.
              diskDevice = builtins.elemAt [
                "/dev/nvme0n1"
                "/dev/nvme0n1"
                "/dev/sda"
                "/dev/sda"
                "/dev/sda"
                "/dev/sda"
              ] i;
            };
          })
        ) (nixpkgs.lib.range 0 5)
      );
    };
}
