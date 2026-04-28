{ pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  vibesPkg = pkgs.callPackage ../pkgs/vibes.nix { };
  codexAcpPkg = pkgs.callPackage ../pkgs/codex-acp.nix { };
  servicePath = agentService.path [
    pkgs.codex
    pkgs.python3
    codexAcpPkg
  ];
in {
  systemd.tmpfiles.rules = [
    "d /workspace/.pi/vibes 0700 agent users - -"
  ];

  systemd.services.vibes = {
    description = "Vibes (Codex backend)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = agentService.serviceDefaults // {
      WorkingDirectory = "/workspace";
      Environment = [
        "HOME=${agentHome}"
        "USER=agent"
        "XDG_CONFIG_HOME=${agentHome}/.config"
        "VIBES_HOST=0.0.0.0"
        "VIBES_PORT=8081"
        "VIBES_DB_PATH=/workspace/.pi/vibes/vibes.db"
        "VIBES_AGENT_NAME=Codex"
        "VIBES_ACP_AGENT=${codexAcpPkg}/bin/codex-acp"
        "PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}"
      ];
      ExecStart = "${vibesPkg}/bin/vibes";
    };
  };
}
