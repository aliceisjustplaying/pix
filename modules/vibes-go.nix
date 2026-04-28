{ lib, pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit lib pkgs; };
  agentHome = agentService.home;
  vibesGoPkg = pkgs.callPackage ../pkgs/vibes-go.nix { };
  codexAcpPkg = pkgs.callPackage ../pkgs/codex-acp.nix { };
  servicePath = agentService.path [
    pkgs.codex
    codexAcpPkg
  ];
in {
  systemd.tmpfiles.rules = [
    "d /workspace/.pi/vibes-go 0700 agent users - -"
  ];

  systemd.services.vibes-go = {
    description = "Vibes Go (Codex backend)";
    after = [ "network-online.target" "vibes.service" ];
    wants = [ "network-online.target" "vibes.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/workspace";
      Environment = [
        "HOME=${agentHome}"
        "USER=agent"
        "XDG_CONFIG_HOME=${agentHome}/.config"
        "VIBES_HOST=0.0.0.0"
        "VIBES_PORT=8082"
        "VIBES_DB_PATH=/workspace/.pi/vibes-go/vibes.db"
        "VIBES_AGENT_NAME=Codex"
        "VIBES_DEFAULT_AGENT=acp"
        "VIBES_PI_ENABLED=false"
        "VIBES_ACP_AGENT=${codexAcpPkg}/bin/codex-acp"
        "PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}"
      ];
      ExecStart = "${vibesGoPkg}/bin/vibes";
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
