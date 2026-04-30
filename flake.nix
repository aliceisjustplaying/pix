{
  description = "pix.mosphere.at - NixOS host for Piclaw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
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
      url = "github:aliceisjustplaying/codex-cli-nix/fix-linux-musl-assets";
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
    system = "aarch64-linux";
    unstablePkgs = import nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
    hostOverlay = final: _prev: {
      agent-browser = llm-agents.packages.${final.stdenv.hostPlatform.system}.agent-browser;
      claude-code-acp = final.callPackage ./pkgs/claude-code-acp { };
      codex-acp = final.callPackage ./pkgs/codex-acp.nix { };
      portless = final.callPackage ./pkgs/portless.nix { };
      vibes = final.callPackage ./pkgs/vibes.nix { };
      vibes-go = final.callPackage ./pkgs/vibes-go.nix { };
      inherit (unstablePkgs)
        gh
        uv
        ;
      bun = unstablePkgs.bun.overrideAttrs (finalAttrs: _oldAttrs: {
        version = "1.3.13";
        src = final.fetchurl {
          url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-aarch64.zip";
          hash = "sha256-cLrkGzkIsKEg4eWMXIrzDnSvrjuNEbDT/djnh937SyI=";
        };
        passthru = unstablePkgs.bun.passthru // {
          sources = unstablePkgs.bun.passthru.sources // {
            "aarch64-linux" = final.fetchurl {
              url = "https://github.com/oven-sh/bun/releases/download/bun-v${finalAttrs.version}/bun-linux-aarch64.zip";
              hash = "sha256-cLrkGzkIsKEg4eWMXIrzDnSvrjuNEbDT/djnh937SyI=";
            };
          };
        };
      });
    };
  in rec {
    packages.${system} = let
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [ hostOverlay ];
      };
    in {
      inherit (pkgs)
        claude-code-acp
        codex-acp
        portless
        vibes
        vibes-go
        ;
    };

    nixosConfigurations.pix = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [
            claude-code.overlays.default
            codex-cli.overlays.default
            hostOverlay
          ];
        }
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        ./hosts/pix/default.nix
      ];
    };
  };
}
