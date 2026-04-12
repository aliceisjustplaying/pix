{ config, lib, pkgs, ... }:
let
  agentHome = "/home/agent";

  servicePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.diffutils
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gh
    pkgs.git
    pkgs.gnupatch
    pkgs.openssh
    pkgs.bun
    pkgs.nodejs_24
    pkgs.python3
    pkgs.jq
    pkgs.procps
    pkgs.sqlite
    pkgs.ffmpeg
    pkgs.yt-dlp
    pkgs.tmux
    pkgs.which
    pkgs.claude-code
    pkgs.codex
  ];
in {
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
    content = ''
      PICLAW_WORKSPACE=/workspace
      PICLAW_STORE=/workspace/.piclaw/store
      PICLAW_DATA=/workspace/.piclaw/data
      PICLAW_WEB_HOST=127.0.0.1
      PICLAW_WEB_PORT=8080
      PICLAW_TRUST_PROXY=1
      PICLAW_WEB_TERMINAL_ENABLED=1
      PICLAW_WEB_PASSKEY_MODE=passkey-only
      PICLAW_AUTOSTART=1
      PICLAW_ASSISTANT_NAME=PiClaw
      PICLAW_DREAM_MODEL=anthropic/claude-sonnet-4-6
      PICLAW_KEYCHAIN_KEY=${config.sops.placeholder.piclaw-keychain-key}
      PICLAW_WEB_TOTP_SECRET=${config.sops.placeholder.piclaw-web-totp-secret}
      PICLAW_WEB_INTERNAL_SECRET=${config.sops.placeholder.piclaw-web-internal-secret}
      CLOUDFLARE_API_TOKEN=${config.sops.placeholder.cloudflare-api-token}
    '';
  };

  sops.templates.agent-web-search-json = {
    restartUnits = [ "agent-secrets.service" ];
    content = ''
      {
        "exaApiKey": "${config.sops.placeholder.exa-api-key}"
      }
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${agentHome}/src 0755 agent users - -"
    "d ${agentHome}/workspace 0750 agent users - -"
    "d ${agentHome}/.local 0755 agent users - -"
    "d ${agentHome}/.local/bin 0755 agent users - -"
    "d ${agentHome}/.pi 0700 agent users - -"
    "d ${agentHome}/.ssh 0700 agent users - -"
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

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/workspace/src/piclaw-live";
      EnvironmentFile = config.sops.templates.piclaw-env.path;
      Environment = [
        "HOME=${agentHome}"
        "USER=agent"
        "XDG_CONFIG_HOME=${agentHome}/.config"
        "PICLAW_LIVE_ROOT=/workspace/src/piclaw-live"
        "PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}"
      ];
      ExecStart = "${pkgs.bun}/bin/bun runtime/src/index.ts";
      Restart = "always";
      RestartSec = "5s";
      TimeoutStartSec = "60s";
      UMask = "0077";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ "${agentHome}" "/workspace" ];
    };
  };
}
