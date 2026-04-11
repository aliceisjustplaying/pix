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
    "${config.home.homeDirectory}/.nix-profile/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
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
      sync-nix = "cd ~/src/pix && git pull && rebuild";
      update = "cd ~/src/piclaw-customizations && git pull && ./scripts/piclaw-update.sh";
      update-force = "cd ~/src/piclaw-customizations && git pull && ./scripts/piclaw-update.sh --force";
      pstatus = "systemctl status tailscaled cloudflared piclaw --no-pager";
      plogs = "journalctl -u piclaw -n 50 --no-pager";
      prestart = "sudo systemctl restart piclaw";
      backup = "sudo systemctl start restic-backups-r2.service && sudo journalctl -u restic-backups-r2.service --no-pager -f";
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "alice";
      user.email = "aliceisjustplaying@gmail.com";
      user.signingKey = "~/.ssh/id_ed25519_github";
      commit.gpgSign = true;
      gpg.format = "ssh";
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
