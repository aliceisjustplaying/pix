{ pkgs, lean ? false }:

let
  home = "/home/agent";
  # lean: service PATH for boxes that only run checkouts (emojistats crawl
  # fleet) — none of the interactive-agent tooling of the full list.
  leanAgentPath = with pkgs; [
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
    bun
    nodejs_24
  ];
  fullAgentPath = with pkgs; [
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
  agentPath = if lean then leanAgentPath else fullAgentPath;

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
    # systemd splits unquoted Environment= values on whitespace (a value with
    # spaces silently truncates at the first one — cost us the archive
    # syncCommand on the emojistats fleet), so quote anything that needs it.
    map (e: if pkgs.lib.hasInfix " " e then "\"${e}\"" else e) ([
      "HOME=${home}"
      "USER=agent"
      "XDG_CONFIG_HOME=${home}/.config"
    ]
    ++ extra
    ++ pkgs.lib.optional useRuntimePath
      "PATH=${home}/.local/bin:${home}/.bun/bin:${makePath pathPackages}");
}
