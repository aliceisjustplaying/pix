{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
  workspaceSrc = "/workspace/src";
  vibesPkg = pkgs.callPackage ../pkgs/vibes.nix { };
  codexAcpPkg = pkgs.callPackage ../pkgs/codex-acp.nix { };
  hermesLauncher = ''
    #!/usr/bin/env bash
    set -euo pipefail
    export HERMES_HOME=/workspace/.hermes
    export PYTHONPATH=/workspace/.hermes/overrides''${PYTHONPATH:+:$PYTHONPATH}
    exec /workspace/.hermes/venv/bin/hermes "$@"
  '';

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
    hcloud
    ncdu
    gdu
    diskus
    ffmpeg
    yt-dlp
    sqlite
    claude-code
    codex
    python3
    uv
    vibesPkg
    codexAcpPkg
  ];

  home.file.".npmrc".text = "prefix=${home}/.local";

  home.file.".local/share/locket" = {
    source = ../tools/locket;
    recursive = true;
  };

  home.file.".local/bin/locket" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail
      exec ${pkgs.python3}/bin/python3 ${home}/.local/share/locket/locket.py "$@"
    '';
  };

  home.file.".local/bin/host-queue" = {
    executable = true;
    text = hostQueueScript;
  };

  # host-follow <unit> [--heartbeat 45] [--max 900]
  #
  # Poll a transient systemd unit on the host until it reaches a terminal
  # state, printing a heartbeat on the configured cadence and exiting
  # with the unit's real result code. Use this instead of `journalctl -f`
  # so the agent doesn't sit silently in a follower stream.
  #
  # Implementation note: host-queue starts units with `systemd-run --collect`,
  # which causes systemd to forget the unit's `Result` once it exits.
  # Polling `systemctl show` therefore returns `Result=success` even for
  # failed runs once they're complete. We instead grep the journal for the
  # systemd-emitted terminal lines (`Deactivated successfully` /
  # `Failed with result`), which are stable and reliable.
  home.file.".local/bin/host-follow" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      unit=""
      heartbeat=45
      max_seconds=900
      tail_lines=40

      while [ "$#" -gt 0 ]; do
        case "$1" in
          --heartbeat) heartbeat="$2"; shift 2 ;;
          --max) max_seconds="$2"; shift 2 ;;
          --tail) tail_lines="$2"; shift 2 ;;
          -h|--help)
            echo "usage: host-follow <unit> [--heartbeat 45] [--max 900] [--tail 40]"
            exit 0
            ;;
          *)
            if [ -z "$unit" ]; then unit="$1"; else
              echo "unexpected arg: $1" >&2; exit 64
            fi
            shift ;;
        esac
      done

      if [ -z "$unit" ]; then
        echo "usage: host-follow <unit> [--heartbeat 45] [--max 900] [--tail 40]" >&2
        exit 64
      fi

      start_ts=$(date +%s)
      last_beat=$start_ts

      echo "[host-follow] watching $unit (heartbeat=$heartbeat s, max=$max_seconds s)"

      # Read the unit's recent journal in one shot. Grep for the systemd-
      # emitted terminal lines because `--collect`'d transient units lose
      # their Result property after exit.
      check_terminal() {
        local journal
        journal="$(ssh -o BatchMode=yes localhost \
          "journalctl --no-pager -n 200 -u $unit -o cat 2>/dev/null" || true)"

        if printf '%s\n' "$journal" | grep -qE 'Failed with result|Main process exited, code=(exited|killed), status=[1-9]'; then
          echo "failed"
          return 0
        fi
        if printf '%s\n' "$journal" | grep -qE 'Deactivated successfully'; then
          echo "success"
          return 0
        fi
        echo "running"
      }

      while :; do
        now=$(date +%s)
        elapsed=$(( now - start_ts ))

        if [ "$elapsed" -ge "$max_seconds" ]; then
          echo "[host-follow] TIMEOUT after $elapsed s; unit $unit still not terminal"
          ssh -o BatchMode=yes localhost "journalctl --no-pager -n $tail_lines -u $unit" || true
          exit 124
        fi

        terminal="$(check_terminal)"
        case "$terminal" in
          success)
            echo "[host-follow] unit $unit succeeded after $elapsed s"
            ssh -o BatchMode=yes localhost "journalctl --no-pager -n $tail_lines -u $unit" || true
            exit 0
            ;;
          failed)
            echo "[host-follow] unit $unit FAILED after $elapsed s"
            ssh -o BatchMode=yes localhost "journalctl --no-pager -n $tail_lines -u $unit" || true
            exit 1
            ;;
        esac

        if [ $(( now - last_beat )) -ge "$heartbeat" ]; then
          last_beat=$now
          echo "[host-follow] still running after $elapsed s"
        fi

        sleep 3
      done
    '';
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

  home.file.".local/bin/hermes" = {
    executable = true;
    text = hermesLauncher;
  };

  home.file.".local/bin/hermes-cli" = {
    executable = true;
    text = hermesLauncher;
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
      pix = "cd /workspace/src/pix";
      pclaw = "cd /workspace/src/piclaw-customizations";
      nfu = "cd /workspace/src/pix && nix flake update && rebuild";
      c = "claude --dangerously-skip-permissions";
      c45 = "claude --dangerously-skip-permissions --model claude-opus-4-5";
      c46 = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]'";
      c47 = "claude --dangerously-skip-permissions --model claude-opus-4-7";
      cr = "claude --dangerously-skip-permissions --resume";
      c45r = "claude --dangerously-skip-permissions --model claude-opus-4-5 --resume";
      c46r = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]' --resume";
      c47r = "claude --dangerously-skip-permissions --model claude-opus-4-7 --resume";
      y = "codex --dangerously-bypass-approvals-and-sandbox";
      yr = "codex --dangerously-bypass-approvals-and-sandbox resume";
      ta = "tmux attach";
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
