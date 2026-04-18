{ lib, pkgs, ... }:
let
  agentHome = "/home/agent";
  vibesPkg = pkgs.callPackage ../pkgs/vibes.nix { };
  codexAcpPkg = pkgs.callPackage ../pkgs/codex-acp.nix { };

  servicePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
    pkgs.openssh
    pkgs.procps
    pkgs.python3
    pkgs.sqlite
    pkgs.which
    pkgs.codex
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

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/workspace";
      Environment = [
        "HOME=${agentHome}"
        "USER=agent"
        "XDG_CONFIG_HOME=${agentHome}/.config"
        "VIBES_HOST=127.0.0.1"
        "VIBES_PORT=8081"
        "VIBES_DB_PATH=/workspace/.pi/vibes/vibes.db"
        "VIBES_AGENT_NAME=Codex"
        "VIBES_ACP_AGENT=${codexAcpPkg}/bin/codex-acp"
        "PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}"
      ];
      ExecStart = "${vibesPkg}/bin/vibes";
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
