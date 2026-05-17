{ pkgs, ... }:

let
  agentHome = "/home/agent";
  runnerIds = [
    "1"
    "2"
    "3"
  ];
  agentWorkDir = "/workspace/agent-worktrees/bluepy";
  tokenFile = "${agentHome}/.config/github-runner/bluepy-token";
  mkRunner = id:
    let
      runnerName = "bluepy-agent-${id}";
      runnerWorkDir = "/workspace/github-runners/${runnerName}";
    in
    {
      enable = true;
      url = "https://github.com/aliceisjustplaying/bluepy";
      name = runnerName;
      tokenFile = tokenFile;
      user = "agent";
      group = "users";
      workDir = runnerWorkDir;
      replace = true;
      extraLabels = [
        "bluepy-agent"
        runnerName
      ];
      extraPackages = with pkgs; [
        agent-browser
        bubblewrap
        bun
        chromium
        claude-code
        codex
        coreutils
        curl
        fd
        firefox
        gh
        git
        gnugrep
        gnused
        jq
        nodejs_24
        openssh
        playwright-driver
        playwright-test
        ripgrep
      ];
      extraEnvironment = {
        HOME = agentHome;
        PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
        PLAYWRIGHT_HOST_PLATFORM_OVERRIDE = "ubuntu-24.04";
        PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      };
      serviceOverrides = {
        ProtectHome = false;
        ReadWritePaths = [
          agentHome
          runnerWorkDir
          agentWorkDir
        ];
      };
    };
in
{
  systemd.tmpfiles.rules = [
    "d ${agentHome}/.config/github-runner 0700 agent users - -"
    "d /workspace/github-runners 0750 agent users - -"
    "d /workspace/agent-worktrees 0750 agent users - -"
    "d ${agentWorkDir} 0750 agent users - -"
  ] ++ map (id: "d /workspace/github-runners/bluepy-agent-${id} 0750 agent users - -") runnerIds;

  services.github-runners = builtins.listToAttrs (map
    (id: {
      name = "bluepy-agent-${id}";
      value = mkRunner id;
    })
    runnerIds);

  systemd.services = builtins.listToAttrs (map
    (id: {
      name = "github-runner-bluepy-agent-${id}";
      value.unitConfig.ConditionPathExists = tokenFile;
    })
    runnerIds);
}
