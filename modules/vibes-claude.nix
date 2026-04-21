{ lib, pkgs, ... }:
let
  agentHome = "/home/agent";
  workingDir = "/home/agent/newmem";
  vibesPkg = pkgs.callPackage ../pkgs/vibes.nix { };
  claudeCodeAcpPkg = pkgs.callPackage ../pkgs/claude-code-acp { };

  servicePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.findutils
    pkgs.git
    pkgs.gnugrep
    pkgs.gnused
    pkgs.jq
    pkgs.nodejs
    pkgs.openssh
    pkgs.procps
    pkgs.python3
    pkgs.sqlite
    pkgs.which
    pkgs.claude-code
    claudeCodeAcpPkg
  ];
in {
  systemd.tmpfiles.rules = [
    "d /workspace/.pi/vibes-claude 0700 agent users - -"
    "d ${workingDir} 0700 agent users - -"
  ];

  systemd.services.vibes-claude = {
    description = "Vibes (Claude Code ACP backend)";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = workingDir;
      Environment = [
        "HOME=${agentHome}"
        "USER=agent"
        "XDG_CONFIG_HOME=${agentHome}/.config"
        "VIBES_HOST=0.0.0.0"
        "VIBES_PORT=8083"
        "VIBES_DB_PATH=/workspace/.pi/vibes-claude/vibes.db"
        "VIBES_AGENT_NAME=Claude"
        "VIBES_ACP_AGENT=${claudeCodeAcpPkg}/bin/claude-code-acp"
        "VIBES_AVAILABLE_MODELS=claude-opus-4-5,claude-opus-4-6[1m],claude-opus-4-7"
        "VIBES_DEFAULT_MODE=bypassPermissions"
        "CLAUDE_CODE_ALWAYS_ENABLE_EFFORT=1"
        "CLAUDE_CODE_EFFORT_LEVEL=max"
        "CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1"
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
