{
  description = "pix2 - NixOS host for Piclaw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    kernel-nixpkgs.url = "github:NixOS/nixpkgs/master";
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

    llm-agents = {
      url = "github:numtide/llm-agents.nix";
    };
  };

  outputs = inputs@{
    self,
    nixpkgs,
    nixpkgs-unstable,
    home-manager,
    disko,
    sops-nix,
    claude-code,
    codex-cli,
    llm-agents,
    ...
  }:
  let
    systems = [ "x86_64-linux" ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    mkPkgs = system:
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
          cli-proxy-api = final.callPackage ./pkgs/cli-proxy-api.nix { };
          codex-acp = final.callPackage ./pkgs/codex-acp.nix { };
          cursor-cli = final.callPackage ./pkgs/cursor-cli.nix { };
          droid = final.callPackage ./pkgs/droid.nix { };
          gogcli = final.callPackage ./pkgs/gogcli.nix { };
          iii = final.callPackage ./pkgs/iii.nix { };
          oracle = final.callPackage ./pkgs/oracle.nix { };
          plausible = final.callPackage ./pkgs/plausible.nix { };
          portless = final.callPackage ./pkgs/portless { };
          tirith = final.callPackage ./pkgs/tirith.nix { };
          vet-run = final.callPackage ./pkgs/vet-run.nix { };
          inherit (unstablePkgs)
            bun
            fastfetch
            gdu
            gh
            jujutsu
            mosh
            tmux
            todoist
            uv
            zellij
            ;
          tsshd = final.callPackage ./pkgs/tsshd.nix { tsshd = unstablePkgs.tsshd; };
        };
      in import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          claude-code.overlays.default
          codex-cli.overlays.default
          hostOverlay
        ];
      };
    mkNixosConfiguration = { system, hostModule }:
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
  in {
    packages = forAllSystems (system:
      let
        pkgs = mkPkgs system;
      in {
        inherit (pkgs)
          agentmemory
          amp-code
          camofox-browser
          cli-proxy-api
          codex-acp
          cursor-cli
          droid
          gogcli
          iii
          oracle
          portless
          tirith
          vet-run
          ;
      });

    nixosConfigurations = {
      pix2 = mkNixosConfiguration {
        system = "x86_64-linux";
        hostModule = ./hosts/pix2/default.nix;
      };
    };
  };
}
