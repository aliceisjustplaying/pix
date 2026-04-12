{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
  workspaceSrc = "/workspace/src";

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

  hostQueueScript = ''
    #!/usr/bin/env bash
    set -euo pipefail

    if [ "$#" -lt 2 ]; then
      echo "usage: $(basename "$0") <job-name> <command>" >&2
      exit 64
    fi

    job_name="$1"
    shift
    command_string="$1"
    command_b64="$(printf '%s' "$command_string" | base64 -w0)"

    exec ssh -o BatchMode=yes localhost /run/current-system/sw/bin/bash -s -- "$job_name" "$command_b64" <<'EOF'
set -euo pipefail
export PATH=${home}/.local/bin:${home}/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin:$PATH

job_name="$1"
command_b64="$2"
command_string="$(printf '%s' "$command_b64" | base64 -d)"
unit_name="''${job_name}-$(date +%s)"

sudo systemd-run \
  --quiet \
  --collect \
  --service-type=exec \
  --uid=agent \
  --gid=users \
  --setenv=HOME=${home} \
  --setenv=USER=agent \
  --setenv=PATH=${home}/.local/bin:${home}/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin \
  --unit "$unit_name" \
  --description "$job_name" \
  /run/current-system/sw/bin/bash -lc "$command_string"

printf 'queued %s\n' "$unit_name"
printf 'follow logs with: ssh localhost sudo journalctl -u %s -f\n' "$unit_name"
EOF
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

  home.file.".local/bin/host-queue" = {
    executable = true;
    text = hostQueueScript;
  };

  # Scripts that work both interactively and from inside piclaw's sandbox.
  home.file.".local/bin/rebuild" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      cd ${workspaceSrc}/pix
      git pull
      exec ${home}/.local/bin/host-queue \
        pix-rebuild \
        "export PATH=${home}/.local/bin:${home}/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin:\$PATH && cd ${workspaceSrc}/pix && sudo nixos-rebuild switch --flake path:${home}/workspace/src/pix#pix"
    '';
  };

  home.file.".local/bin/update" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      quoted_args=()
      for arg in "$@"; do
        quoted_args+=("$(printf '%q' "$arg")")
      done
      args_string="''${quoted_args[*]}"
      cd ${workspaceSrc}/piclaw-customizations
      git pull
      exec ${home}/.local/bin/host-queue \
        piclaw-update \
        "export PATH=${home}/.local/bin:${home}/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin:\$PATH && cd ${workspaceSrc}/piclaw-customizations && sudo ./scripts/piclaw-update-host.sh''${args_string:+ ''${args_string}}"
    '';
  };

  home.file.".local/bin/rollback" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      quoted_args=()
      for arg in "$@"; do
        quoted_args+=("$(printf '%q' "$arg")")
      done
      args_string="''${quoted_args[*]}"
      exec ${home}/.local/bin/host-queue \
        piclaw-rollback \
        "export PATH=${home}/.local/bin:${home}/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin:\$PATH && cd ${workspaceSrc}/piclaw-customizations && sudo ./scripts/piclaw-rollback-host.sh''${args_string:+ ''${args_string}}"
    '';
  };

  home.file.".local/bin/verify-deploy" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      cd ${workspaceSrc}/piclaw-customizations
      exec ./scripts/piclaw-verify-deploy.sh "$@"
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
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec ${home}/.local/bin/host-queue piclaw-restart "sudo systemctl restart piclaw"
    '';
  };

  home.file.".local/bin/backup" = {
    executable = true;
    text = hostCmd ''"sudo systemctl start restic-backups-r2.service && sudo journalctl -u restic-backups-r2.service --no-pager -f"'';
  };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      sync-nix = "cd /workspace/src/pix && git pull && rebuild";
      update-force = "cd /workspace/src/piclaw-customizations && git pull && sudo ./scripts/piclaw-update-host.sh --force";
      rollback-force = "rollback";
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
