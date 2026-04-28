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
    "d /workspace/.pi/vibes-go 0700 agent users - -"
  ];

  systemd.services.vibes-go = {
    description = "Vibes Go (Codex backend)";
    after = [ "network-online.target" "vibes.service" ];
    wants = [ "network-online.target" "vibes.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = agentService.serviceDefaults // {
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
        "VIBES_ACP_AGENT=${pkgs.codex-acp}/bin/codex-acp"
        "PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}"
      ];
      ExecStart = "${pkgs.vibes-go}/bin/vibes";
    };
  };
}
