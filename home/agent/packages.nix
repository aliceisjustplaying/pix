{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;
in
{
  home.sessionVariables = {
    __EGL_VENDOR_LIBRARY_DIRS = "/run/opengl-driver/share/glvnd/egl_vendor.d";
    EDITOR = "vim";
    LIBGL_DRIVERS_PATH = "/run/opengl-driver/lib/dri";
    PAGER = "less -FR";
    PLAYWRIGHT_BROWSERS_PATH = "${pkgs.playwright-driver.browsers}";
    PLAYWRIGHT_HOST_PLATFORM_OVERRIDE = "ubuntu-24.04";
    PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
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
    zellij
    droid
    amp-code
    cli-proxy-api
    claude-code
    codex
    codex-acp
    python3
    uv
    agent-browser
    firefox
    playwright-driver
    playwright-test
  ];
}
