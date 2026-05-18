{
  description = "pix.mosphere.at - NixOS host for Piclaw";

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
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    forAllSystems = nixpkgs.lib.genAttrs systems;
    mkPkgs = system:
      let
        unstablePkgs = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
        hostOverlay = final: _prev: {
          agent-browser = llm-agents.packages.${final.stdenv.hostPlatform.system}.agent-browser;
          amp-code = final.callPackage ./pkgs/amp.nix { };
          claude-code-acp = final.callPackage ./pkgs/claude-code-acp { };
          cli-proxy-api = final.callPackage ./pkgs/cli-proxy-api.nix { };
          codex-acp = final.callPackage ./pkgs/codex-acp.nix { };
          droid = final.callPackage ./pkgs/droid.nix { };
          gogcli = final.callPackage ./pkgs/gogcli.nix { };
          portless = final.callPackage ./pkgs/portless { };
          inherit (unstablePkgs)
            bun
            fastfetch
            gdu
            gh
            jujutsu
            mosh
            tmux
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
          amp-code
          claude-code-acp
          cli-proxy-api
          codex-acp
          droid
          gogcli
          portless
          ;
      });

    nixosConfigurations = {
      pix = mkNixosConfiguration {
        system = "aarch64-linux";
        hostModule = ./hosts/pix/default.nix;
      };

      pix-amd64 = mkNixosConfiguration {
        system = "x86_64-linux";
        hostModule = ./hosts/pix-amd64/default.nix;
      };
    };
  };
}
