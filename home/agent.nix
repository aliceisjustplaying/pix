{ config, pkgs, ... }:
{
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
    PAGER = "less -FR";
  };

  home.sessionPath = [
    "${config.home.homeDirectory}/.local/bin"
    "${config.home.homeDirectory}/.bun/bin"
  ];

  home.packages = with pkgs; [
    bun
    nodejs_24
    gh
    ffmpeg
    yt-dlp
    sqlite
    claude-code
    codex
    python3
    uv
  ];

  # npm tries to install globals into the read-only Nix store.
  # Redirect to ~/.local so `pi install npm:…` works.
  home.file.".npmrc".text = "prefix=${config.home.homeDirectory}/.local";

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      rebuild = "sudo nixos-rebuild switch --flake ${config.home.homeDirectory}/src/pix#pix";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519_github";
        identitiesOnly = true;
        extraOptions.StrictHostKeyChecking = "accept-new";
      };
    };
  };
}
