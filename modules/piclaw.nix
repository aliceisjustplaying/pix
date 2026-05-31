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

  sops.secrets.github-clone-key = {
    restartUnits = [ "agent-secrets.service" ];
  };
  sops.secrets.gog-oauth-client-json = {
    restartUnits = [ "agent-secrets.service" ];
  };

  sops.templates.piclaw-env = {
    restartUnits = [ "piclaw.service" ];
    content = tmpl ../files/sops/piclaw.env {
      piclawKeychainKey = config.sops.placeholder.piclaw-keychain-key;
      piclawWebTotpSecret = config.sops.placeholder.piclaw-web-totp-secret;
      piclawWebInternalSecret = config.sops.placeholder.piclaw-web-internal-secret;
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
    "d ${agentHome}/.config 0700 agent users - -"
    "z ${agentHome}/.config 0700 agent users - -"
    "d ${agentHome}/.config/gog 0700 agent users - -"
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
      ExecStart = pkgs.writeShellScript "setup-agent-secrets" (tmpl ../files/piclaw/setup-agent-secrets.sh {
        inherit agentHome;
        githubCloneKeyPath = config.sops.secrets.github-clone-key.path;
        gogOAuthClientJsonPath = config.sops.secrets.gog-oauth-client-json.path;
        agentWebSearchJsonPath = config.sops.templates.agent-web-search-json.path;
      });
    };
  };

  # Authorizes piclaw's local key for SSH-based host commands (rebuild, etc.)
  users.users.agent.openssh.authorizedKeys.keyFiles = [
    ../keys/piclaw-local.pub
  ];

  systemd.services.piclaw = {
    description = "Piclaw";
    after = [ "network-online.target" "agent-secrets.service" ];
    wants = [ "network-online.target" "agent-secrets.service" ];
    enable = false;
    wantedBy = lib.mkForce [ ];
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
}
