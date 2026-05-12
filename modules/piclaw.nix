{ config, lib, pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  tmpl = import ../lib/template.nix;

  sharpNativeLibraryPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
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
      ExecStart = pkgs.writeShellScript "setup-agent-secrets" (tmpl ../files/piclaw/setup-agent-secrets.sh {
        inherit agentHome;
        githubCloneKeyPath = config.sops.secrets.github-clone-key.path;
        agentWebSearchJsonPath = config.sops.templates.agent-web-search-json.path;
      });
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
    unitConfig.ConditionPathExists = "/workspace/src/camofox-browser/server.js";

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
      Environment = agentService.env {
        pathPackages = [ pkgs.python3 ];
        extra = [
          "PICLAW_LIVE_ROOT=/workspace/src/piclaw-live"
          "PICLAW_AGENT_BACKEND=codex-app-server"
          "PICLAW_STARTUP_WARM_DEFAULT_CHAT=true"
          "LD_LIBRARY_PATH=${sharpNativeLibraryPath}"
        ];
      };
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
      Environment = agentService.env {
        pathPackages = [ pkgs.python3 ];
        extra = [
          "GMAIL_STATE_DIR=/workspace/.pi/gmail-channel"
          "GMAIL_PICLAW_DATA_DIR=/workspace/.piclaw/data"
          "GMAIL_PICLAW_CHAT_JID=web:default"
          "HERMES_NOTIFY_TARGET=discord:#trinity-home"
          "HERMES_NOTIFY_PYTHON=/workspace/.hermes/venv/bin/python3"
          "HERMES_NOTIFY_AGENT_DIR=/workspace/src/hermes-live"
        ];
      };
      ExecStart = "${pkgs.bun}/bin/bun run daemon.ts";
    };
  };
}
