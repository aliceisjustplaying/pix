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
      url = "github:aliceisjustplaying/codex-cli-nix/codex/fix-0-124-update";
      inputs.nixpkgs.follows = "nixpkgs";
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
