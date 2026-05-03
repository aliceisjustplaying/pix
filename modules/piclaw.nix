{ config, lib, pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  tmpl = import ../lib/template.nix;
  guardedNixosRebuild = lib.hiPrio (pkgs.writeShellScriptBin "nixos-rebuild" ''
    set -euo pipefail

    real_nixos_rebuild="${pkgs.nixos-rebuild}/bin/nixos-rebuild"
    cgroup="$(cat /proc/self/cgroup 2>/dev/null || true)"

    if [ "''${PICLAW_NIXOS_REBUILD_DETACHED:-}" = "1" ] \
      || ! printf '%s\n' "$cgroup" | grep -q '/piclaw.service'; then
      exec "$real_nixos_rebuild" "$@"
    fi

    unit_name="pix-rebuild-$(date +%s)"
    run_systemd=("${pkgs.systemd}/bin/systemd-run")
    if [ "$(id -u)" -ne 0 ]; then
      run_systemd=("/run/wrappers/bin/sudo" "''${run_systemd[@]}")
    fi

    exec "''${run_systemd[@]}" \
      --quiet \
      --collect \
      --service-type=exec \
      --setenv=PICLAW_NIXOS_REBUILD_DETACHED=1 \
      --setenv=HOME=/root \
      --setenv=PATH=/run/wrappers/bin:/run/current-system/sw/bin \
      --unit "$unit_name" \
      --description "Detached NixOS rebuild launched from piclaw.service" \
      "$real_nixos_rebuild" "$@"
  '');

  servicePath = agentService.path [
    pkgs.curl
    pkgs.diffutils
    pkgs.ripgrep
    pkgs.fd
    pkgs.gnumake
    pkgs.tree
    pkgs.unzip
    pkgs.zip
    pkgs.shellcheck
    pkgs.shfmt
    pkgs.gh
    pkgs.ghstack
    pkgs.gnupatch
    pkgs.bun
    pkgs.nodejs_24
    pkgs.python3
    pkgs.ffmpeg
    pkgs.yt-dlp
    pkgs.tmux
    pkgs.claude-code
    pkgs.codex
  ];
  sharpNativeLibraryPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
  ];
in {
  environment.systemPackages = [
    guardedNixosRebuild
  ];

  sops.secrets.piclaw-keychain-key = { };
  sops.secrets.piclaw-web-totp-secret = { };
  sops.secrets.piclaw-web-internal-secret = { };
  sops.secrets.exa-api-key = { };
  sops.secrets.cloudflare-api-token = { };

  sops.secrets.github-clone-key = {
    restartUnits = [ "agent-secrets.service" ];
  };

  sops.templates.piclaw-env = {
    restartUnits = [ "piclaw.service" ];
    content = tmpl ../files/sops/piclaw.env {
      piclawKeychainKey = config.sops.placeholder.piclaw-keychain-key;
      piclawWebTotpSecret = config.sops.placeholder.piclaw-web-totp-secret;
      piclawWebInternalSecret = config.sops.placeholder.piclaw-web-internal-secret;
      cloudflareApiToken = config.sops.placeholder.cloudflare-api-token;
    };
  };

  sops.templates.agent-web-search-json = {
    restartUnits = [ "agent-secrets.service" ];
    content = tmpl ../files/sops/agent-web-search.json {
      exaApiKey = config.sops.placeholder.exa-api-key;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${agentHome}/src 0755 agent users - -"
    "d ${agentHome}/workspace 0750 agent users - -"
    "d ${agentHome}/.local 0755 agent users - -"
    "d ${agentHome}/.local/bin 0755 agent users - -"
    "d ${agentHome}/.pi 0700 agent users - -"
    "d ${agentHome}/.ssh 0700 agent users - -"
    "d /workspace/.pi/gmail-channel 0700 agent users - -"
    "d /usr/local/bin 0755 root root - -"
    "L+ /workspace - - - - ${agentHome}/workspace"
  ];

  systemd.services.agent-secrets = {
    description = "Copy decrypted secrets for agent user";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "setup-agent-secrets" ''
        install -m 0400 -o agent -g users \
          ${config.sops.secrets.github-clone-key.path} \
          ${agentHome}/.ssh/id_ed25519_github

        install -m 0400 -o agent -g users \
          ${config.sops.templates.agent-web-search-json.path} \
          ${agentHome}/.pi/web-search.json
      '';
    };
  };

  # Authorizes piclaw's local key for SSH-based host commands (rebuild, etc.)
  users.users.agent.openssh.authorizedKeys.keyFiles = [
    ../keys/piclaw-local.pub
  ];

  systemd.services.camofox = {
    description = "Camofox Browser - Anti-detection browser REST API";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/workspace/src/camofox-browser";
      Environment = [
        "HOME=${agentHome}"
        "NODE_ENV=production"
        "CAMOFOX_PORT=9377"
        "PATH=${lib.makeBinPath [ pkgs.nodejs_24 pkgs.yt-dlp pkgs.coreutils pkgs.bash ]}"
      ];
      ExecStart = "${pkgs.nodejs_24}/bin/node server.js";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  systemd.services.piclaw = {
    description = "Piclaw";
    after = [ "network-online.target" "agent-secrets.service" ];
    wants = [ "network-online.target" "agent-secrets.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "/workspace/src/piclaw-live/runtime/src/index.ts";

    serviceConfig = agentService.serviceDefaults // {
      WorkingDirectory = "/workspace/src/piclaw-live";
      EnvironmentFile = config.sops.templates.piclaw-env.path;
      Environment = [
        "HOME=${agentHome}"
        "USER=agent"
        "XDG_CONFIG_HOME=${agentHome}/.config"
        "PICLAW_LIVE_ROOT=/workspace/src/piclaw-live"
        "PICLAW_AGENT_BACKEND=codex-app-server"
        "PICLAW_STARTUP_WARM_DEFAULT_CHAT=true"
        "LD_LIBRARY_PATH=${sharpNativeLibraryPath}"
        "PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}"
      ];
      ExecStart = "${pkgs.bun}/bin/bun runtime/src/index.ts";
    };
  };

  systemd.services.gmail-channel-daemon = {
    description = "Gmail Channel Daemon";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = "${agentHome}/gmail-channel-plugin/daemon.ts";

    serviceConfig = agentService.serviceDefaults // {
      WorkingDirectory = "${agentHome}/gmail-channel-plugin";
      EnvironmentFile = "-/workspace/.pi/gmail-channel.env";
      Environment = [
        "HOME=${agentHome}"
        "USER=agent"
        "XDG_CONFIG_HOME=${agentHome}/.config"
        "GMAIL_STATE_DIR=/workspace/.pi/gmail-channel"
        "GMAIL_PICLAW_DATA_DIR=/workspace/.piclaw/data"
        "GMAIL_PICLAW_CHAT_JID=web:default"
        "HERMES_NOTIFY_TARGET=discord:#trinity-home"
        "HERMES_NOTIFY_PYTHON=/workspace/.hermes/venv/bin/python3"
        "HERMES_NOTIFY_AGENT_DIR=/workspace/src/hermes-live"
        "PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}"
      ];
      ExecStart = "${pkgs.bun}/bin/bun run daemon.ts";
    };
  };
}
