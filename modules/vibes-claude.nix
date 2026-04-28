{ pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  workingDir = "/home/agent/newmem";
  vibesPkg = pkgs.callPackage ../pkgs/vibes.nix { };
  claudeCodeAcpPkg = pkgs.callPackage ../pkgs/claude-code-acp { };
  servicePath = agentService.path [
    pkgs.nodejs
    pkgs.claude-code
    pkgs.python3
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

    serviceConfig = agentService.serviceDefaults // {
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
    };
  };
}
