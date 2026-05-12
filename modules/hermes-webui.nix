{ pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  hermesHome = "/workspace/.hermes";
  webuiRepo = "/workspace/src/hermes-webui";
  webuiState = "${hermesHome}/webui";
  port = 8787;
  tmpl = import ../lib/template.nix;

  bootstrap = pkgs.writeShellScript "hermes-webui-bootstrap" (tmpl ../files/hermes-webui/bootstrap.sh {
    inherit webuiRepo webuiState;
    git = "${pkgs.git}/bin/git";
  });
in {
  systemd.tmpfiles.rules = [
    "d ${webuiState} 0700 agent users - -"
  ];

  systemd.services."hermes-webui" = {
    description = "Hermes WebUI (nesquena/hermes-webui)";
    after = [ "network-online.target" "hermes-gateway.service" "tailscaled.service" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.git ];

    serviceConfig = agentService.serviceDefaults // {
      WorkingDirectory = "/workspace";
      Environment = agentService.env {
        extra = [
          "PYTHONUNBUFFERED=1"
          "HERMES_HOME=${hermesHome}"
          "HERMES_WEBUI_HOST=0.0.0.0"
          "HERMES_WEBUI_PORT=${toString port}"
          "HERMES_WEBUI_STATE_DIR=${webuiState}"
          "HERMES_WEBUI_AGENT_DIR=/workspace/src/hermes-live"
          "HERMES_WEBUI_PYTHON=${hermesHome}/venv/bin/python"
          "HERMES_WEBUI_DEFAULT_WORKSPACE=${agentHome}"
        ];
      };
      ExecStartPre = bootstrap;
      ExecStart = "${hermesHome}/venv/bin/python ${webuiRepo}/server.py";
      RestartSec = "10s";
      TimeoutStartSec = "90s";
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}
