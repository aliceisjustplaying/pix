{ pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  servicePath = agentService.path [
    pkgs.codex
    pkgs.codex-acp
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
        "VIBES_HOST=100.74.251.100"
        "VIBES_PORT=8081"
        "VIBES_DB_PATH=/workspace/.pi/vibes/vibes.db"
        "VIBES_AGENT_NAME=Codex"
        "VIBES_DEFAULT_AGENT=acp"
        "VIBES_PI_ENABLED=false"
        "CODEX_PATH=${pkgs.codex}/bin/codex"
        "VIBES_ACP_AGENT=${pkgs.codex-acp}/bin/codex-acp"
        "PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}"
      ];
      ExecStart = "${pkgs.vibes}/bin/vibes";
    };
  };
}
