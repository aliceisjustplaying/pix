{ pkgs }:

let
  home = "/home/agent";
  agentPath = with pkgs; [
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

  makePath = extra: pkgs.lib.makeBinPath (agentPath ++ extra);
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

  runtimePath = makePath;

  env = {
    extra ? [ ],
    pathPackages ? [ ],
    useRuntimePath ? true,
  }:
    assert pkgs.lib.assertMsg (useRuntimePath || pathPackages == [ ])
      "agent-service.env: pathPackages was set but useRuntimePath = false, so it would be silently dropped";
    [
      "HOME=${home}"
      "USER=agent"
      "XDG_CONFIG_HOME=${home}/.config"
    ]
    ++ extra
    ++ pkgs.lib.optional useRuntimePath
      "PATH=${home}/.local/bin:${home}/.bun/bin:${makePath pathPackages}";
}
