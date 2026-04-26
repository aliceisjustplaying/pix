{
  description = "pix.mosphere.at - NixOS host for Piclaw";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
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
  in {
    nixosConfigurations.pix = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit inputs; };
      modules = [
        {
          nixpkgs.config.allowUnfree = true;
          nixpkgs.overlays = [
            claude-code.overlays.default
            codex-cli.overlays.default
            (final: _prev: {
              agent-browser = llm-agents.packages.${final.stdenv.hostPlatform.system}.agent-browser;
            })
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
