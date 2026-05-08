{ pkgs }:

let
  home = "/home/agent";
  corePathPackages = with pkgs; [
    bash
    coreutils
    findutils
    git
    gnugrep
    gnused
    jq
    openssh
    procps
    sqlite
    which
  ];
  agentRuntimePackages = with pkgs; [
    curl
    diffutils
    ripgrep
    fd
    gnumake
    tree
    unzip
    zip
    shellcheck
    shfmt
    gh
    ghstack
    gnupatch
    bun
    nodejs_24
    ffmpeg
    yt-dlp
    tmux
    claude-code
    codex
    codex-acp
  ];

  makePath = packages: pkgs.lib.makeBinPath (corePathPackages ++ packages);
in {
  inherit home;

  serviceDefaults = {
    Type = "simple";
    User = "agent";
    Group = "users";
    Restart = "always";
    RestartSec = "5s";
    TimeoutStartSec = "60s";
    UMask = "0077";
    PrivateTmp = true;
    ProtectSystem = "strict";
    ProtectHome = false;
    ReadWritePaths = [ "/home/agent" "/workspace" ];
  };

  path = makePath;
  runtimePath = extraPackages: makePath (agentRuntimePackages ++ extraPackages);

  env = {
    extra ? [ ],
    pathPackages ? [ ],
    useRuntimePath ? true,
  }:
    [
      "HOME=${home}"
      "USER=agent"
      "XDG_CONFIG_HOME=${home}/.config"
    ]
    ++ extra
    ++ pkgs.lib.optional useRuntimePath
      "PATH=${home}/.local/bin:${home}/.bun/bin:${makePath (agentRuntimePackages ++ pathPackages)}";
}
