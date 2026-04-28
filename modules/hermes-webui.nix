{ pkgs, ... }:
let
  agentHome = "/home/agent";
  hermesHome = "/workspace/.hermes";
  webuiRepo = "/workspace/src/hermes-webui";
  webuiState = "${hermesHome}/webui";
  port = 8787;

  webuiPatches = ../patches/hermes-webui;

  bootstrap = pkgs.writeShellScript "hermes-webui-bootstrap" ''
    set -euo pipefail
    mkdir -p "${webuiState}" /workspace/src
    if [ ! -d "${webuiRepo}/.git" ]; then
      rm -rf "${webuiRepo}"
      ${pkgs.git}/bin/git clone --depth=1 https://github.com/nesquena/hermes-webui.git "${webuiRepo}"
    else
      ${pkgs.git}/bin/git -C "${webuiRepo}" reset --hard HEAD
      ${pkgs.git}/bin/git -C "${webuiRepo}" pull --ff-only || true
    fi
    for p in ${webuiPatches}/*.patch; do
      [ -e "$p" ] || continue
      ${pkgs.git}/bin/git -C "${webuiRepo}" apply "$p" || {
        echo "patch $p failed" >&2; exit 1;
      }
    done
  '';
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

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/workspace";
      Environment = [
        "HOME=${agentHome}"
        "USER=agent"
        "PYTHONUNBUFFERED=1"
        "HERMES_HOME=${hermesHome}"
        "HERMES_WEBUI_HOST=0.0.0.0"
        "HERMES_WEBUI_PORT=${toString port}"
        "HERMES_WEBUI_STATE_DIR=${webuiState}"
        "HERMES_WEBUI_AGENT_DIR=/workspace/src/hermes-live"
        "HERMES_WEBUI_PYTHON=${hermesHome}/venv/bin/python"
        "HERMES_WEBUI_DEFAULT_WORKSPACE=${agentHome}"
      ];
      ExecStartPre = bootstrap;
      ExecStart = "${hermesHome}/venv/bin/python ${webuiRepo}/server.py";
      Restart = "always";
      RestartSec = "10s";
      UMask = "0077";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ agentHome "/workspace" ];
    };
  };

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ port ];
}
