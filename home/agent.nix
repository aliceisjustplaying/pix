{ config, pkgs, ... }:
let
  home = config.home.homeDirectory;
  workspaceSrc = "/workspace/src";
  vibesPkg = pkgs.callPackage ../pkgs/vibes.nix { };
  codexAcpPkg = pkgs.callPackage ../pkgs/codex-acp.nix { };

  # Render a script from files/bin/<name>.sh. Pass replacements for the
  # @placeholder@ tokens the file uses (replaceVars errors on unused vars).
  binSrc = name: replacements:
    pkgs.replaceVars (../files/bin + "/${name}.sh") replacements;

  # Files with no placeholders; included verbatim.
  binStatic = name: ../files/bin + "/${name}.sh";
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
    hcloud
    ncdu
    gdu
    diskus
    ffmpeg
    yt-dlp
    sqlite
    claude-code
    codex
    python3
    uv
    vibesPkg
    codexAcpPkg
    agent-browser
  ];

  home.file.".npmrc".text = "prefix=${home}/.local";

  home.file.".claude/CLAUDE.md".source = ../files/claude/CLAUDE.md;
  home.file.".codex/AGENTS.md".source = ../files/codex/AGENTS.md;

  # SSH-based host commands work from inside piclaw's sandbox: the piclaw
  # systemd unit runs with ProtectSystem=strict, so commands that write
  # outside ~/ (nixos-rebuild, systemctl) tunnel through SSH to localhost.
  # An ed25519 keypair (keys/piclaw-local.pub) is authorized for agent@localhost.
  home.file.".local/bin/host-queue"    = { executable = true; source = binSrc "host-queue"    { inherit home; }; };
  home.file.".local/bin/host-follow"   = { executable = true; source = binStatic "host-follow"; };
  home.file.".local/bin/host-result"   = { executable = true; source = binStatic "host-result"; };
  home.file.".local/bin/rebuild"       = { executable = true; source = binSrc "rebuild"       { inherit home workspaceSrc; }; };
  home.file.".local/bin/update"        = { executable = true; source = binSrc "update"        { inherit home workspaceSrc; }; };
  home.file.".local/bin/rollback"      = { executable = true; source = binSrc "rollback"      { inherit home workspaceSrc; }; };
  home.file.".local/bin/verify-deploy" = { executable = true; source = binSrc "verify-deploy" { inherit workspaceSrc; }; };
  home.file.".local/bin/prestart"      = { executable = true; source = binSrc "prestart"      { inherit home; }; };
  home.file.".local/bin/pstatus"       = { executable = true; source = binStatic "pstatus"; };
  home.file.".local/bin/plogs"         = { executable = true; source = binStatic "plogs"; };
  home.file.".local/bin/backup"        = { executable = true; source = binStatic "backup"; };
  home.file.".local/bin/hermes"        = { executable = true; source = binStatic "hermes"; };
  home.file.".local/bin/hermes-cli"    = { executable = true; source = binStatic "hermes"; };

  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -lah";
      sync-nix = "cd /workspace/src/pix && git pull && rebuild";
      update-force = "cd /workspace/src/piclaw-customizations && git pull && sudo ./scripts/piclaw-update-host.sh --force";
      rollback-force = "rollback";
      pix = "cd /workspace/src/pix";
      pclaw = "cd /workspace/src/piclaw-customizations";
      nfu = "cd /workspace/src/pix && nix flake update && rebuild";
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
