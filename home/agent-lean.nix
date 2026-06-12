# Trimmed agent profile for the ephemeral emojistats crawl boxes: just enough
# to run and operate the crawler checkout. No interactive-agent tooling, no
# browsers — smaller closure, fewer flaky fetches on install (gogcli's go
# vendor fetch already cost one launch attempt).
{ pkgs, ... }:

{
  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  home.sessionVariables = {
    EDITOR = "vim";
    PAGER = "less -FR";
  };

  home.sessionPath = [
    "/home/agent/.local/bin"
    "/home/agent/.bun/bin"
    "/home/agent/.nix-profile/bin"
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
  ];

  home.packages = with pkgs; [
    bun
    nodejs_24
    sqlite
    ncdu
    # node-gyp toolchain: better-sqlite3 builds its binding from source on
    # every fresh `bun install`.
    python3
    gcc
    gnumake
  ];
}
