{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;

  # SSH-based host commands for use inside the sandboxed piclaw service.
  # The piclaw systemd unit runs with ProtectSystem=strict, so commands
  # that write outside ~/  (nixos-rebuild, systemctl) must go through
  # SSH to localhost.  An ed25519 keypair (keys/piclaw-local.pub) is
  # authorized for agent@localhost to make this work.
  hostCmd = cmd: ''
    #!/usr/bin/env bash
    set -euo pipefail
    exec ssh -o BatchMode=yes localhost ${cmd}
  '';
in {
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
    PAGER = "less -FR";
  };

  home.sessionPath = [
    "${home}/.local/bin"
    "${home}/.bun/bin"
    "${home}/.nix-profile/bin"
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

  home.file.".npmrc".text = "prefix=${home}/.local";

  # Scripts that work both interactively and from inside piclaw's sandbox.
  home.file.".local/bin/rebuild" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      cd ${home}/src/pix
      git pull
      ssh -o BatchMode=yes localhost "export PATH=${home}/.local/bin:${home}/.bun/bin:/usr/local/bin:\$PATH && sudo nixos-rebuild switch --flake ${home}/src/pix#pix"
    '';
  };

  home.file.".local/bin/update" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      cd ${home}/src/piclaw-customizations
      git pull
      ssh -o BatchMode=yes localhost "export PATH=${home}/.local/bin:${home}/.bun/bin:/usr/local/bin:\$PATH && cd ${home}/src/piclaw-customizations && ./scripts/piclaw-update.sh $*"
    '';
  };

  home.file.".local/bin/pstatus" = {
    executable = true;
    text = hostCmd ''"systemctl status tailscaled cloudflared piclaw --no-pager"'';
  };

  home.file.".local/bin/plogs" = {
    executable = true;
    text = hostCmd ''"journalctl -u piclaw -n 50 --no-pager"'';
  };

  home.file.".local/bin/prestart" = {
    executable = true;
    text = hostCmd ''"sudo systemctl restart piclaw"'';
  };

  home.file.".local/bin/backup" = {
    executable = true;
    text = hostCmd ''"sudo systemctl start restic-backups-r2.service && sudo journalctl -u restic-backups-r2.service --no-pager -f"'';
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      sync-nix = "cd ~/src/pix && git pull && rebuild";
      update-force = "cd ~/src/piclaw-customizations && git pull && ./scripts/piclaw-update.sh --force";
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
      "localhost" = {
        user = "agent";
        identityFile = "~/.ssh/id_ed25519_local";
        identitiesOnly = true;
        extraOptions.StrictHostKeyChecking = "accept-new";
      };
    };
  };
}
