{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
  workspaceSrc = "/workspace/src";

  # Render a script from files/bin/<name>.sh. Pass replacements for the
  # @placeholder@ tokens the file uses (replaceVars errors on unused vars).
  binSrc = name: replacements:
    pkgs.replaceVars (../files/bin + "/${name}.sh") replacements;

  # Files with no placeholders; included verbatim.
  binStatic = name: ../files/bin + "/${name}.sh";

  binFiles = {
    host-result = binStatic "host-result";
    rebuild = binStatic "rebuild";
    update = binStatic "update";
    rollback = binStatic "rollback";
    verify-deploy = binSrc "verify-deploy" { inherit workspaceSrc; };
    pix-update-pins = binStatic "pix-update-pins";
    piclaw-restart = binStatic "piclaw-restart";
    piclaw-status = binStatic "piclaw-status";
    piclaw-logs = binStatic "piclaw-logs";
    backup = binStatic "backup";
    hermes = binStatic "hermes";
  };
in {
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
    PAGER = "less -FR";
  };

  home.sessionPath = [
    "${home}/.local/bin"
    "${home}/.bun/bin"
    "${home}/.nix-profile/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
  ];

  home.packages = with pkgs; [
    bun
    nodejs_24
    gh
    jujutsu
    portless
    hcloud
    ncdu
    gdu
    diskus
    go_1_26
    ffmpeg
    yt-dlp
    sqlite
    tsshd
    claude-code
    codex
    python3
    uv
    agent-browser
  ];

  # Host commands run through fixed NixOS-declared systemd units. Sudo is
  # scoped to exact `systemctl start --no-block <unit>` commands.
  home.file = pkgs.lib.mapAttrs'
    (name: source: {
      name = ".local/bin/${name}";
      value = {
        executable = true;
        inherit source;
      };
    })
    binFiles // {
      ".npmrc".text = "prefix=${home}/.local";
      ".claude/CLAUDE.md".source = ../files/claude/CLAUDE.md;
      ".codex/AGENTS.md".source = ../files/codex/AGENTS.md;
    };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      sync-nix = "rebuild";
      update-force = "update --force";
      rollback-force = "rollback";
      pix = "cd /workspace/src/pix";
      pclaw = "cd /workspace/src/piclaw-customizations";
      nfu = "pix-update-pins && rebuild";
      c = "claude --dangerously-skip-permissions";
      c45 = "claude --dangerously-skip-permissions --model claude-opus-4-5";
      c46 = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]'";
      c47 = "claude --dangerously-skip-permissions --model claude-opus-4-7";
      cr = "claude --dangerously-skip-permissions --resume";
      c45r = "claude --dangerously-skip-permissions --model claude-opus-4-5 --resume";
      c46r = "claude --dangerously-skip-permissions --model 'claude-opus-4-6[1m]' --resume";
      c47r = "claude --dangerously-skip-permissions --model claude-opus-4-7 --resume";
      y = "codex --dangerously-bypass-approvals-and-sandbox";
      yr = "codex --dangerously-bypass-approvals-and-sandbox resume";
      ta = "tmux attach";
    };
  };

  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
    escapeTime = 0;
    baseIndex = 1;
    extraConfig = builtins.readFile ../files/tmux/tmux.conf;
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = "alice";
      user.email = "aliceisjustplaying@gmail.com";
      user.signingKey = "~/.ssh/id_ed25519_github";
      commit.gpgSign = true;
      gpg.format = "ssh";
      init.defaultBranch = "main";
      pull.rebase = false;
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "github.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519_github";
        identitiesOnly = true;
        extraOptions.StrictHostKeyChecking = "accept-new";
      };
      "localhost" = {
        user = "agent";
        identityFile = "~/.ssh/id_ed25519_local";
        identitiesOnly = true;
        extraOptions.StrictHostKeyChecking = "accept-new";
      };
    };
  };
}
