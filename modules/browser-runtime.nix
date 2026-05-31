{ config, lib, pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  browserNativeLibraryPath = lib.makeLibraryPath config.programs.nix-ld.libraries;
in
{
  hardware.graphics.enable = true;

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      gtk3
      glib
      dbus-glib
      alsa-lib
      nss
      nspr
      xorg.libX11
      xorg.libXcomposite
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXrandr
      xorg.libXtst
      xorg.libXScrnSaver
      xorg.libxcb
      xorg.libXi
      pango
      cairo
      atk
      at-spi2-atk
      cups.lib
      libdrm
      mesa
      expat
      gdk-pixbuf
      fontconfig
      freetype
    ];
  };

  systemd.services.camofox = {
    description = "Camofox Browser - Anti-detection browser REST API";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = agentHome;
      Environment = [
        "HOME=${agentHome}"
        "NODE_ENV=production"
        "CAMOFOX_HOST=127.0.0.1"
        "CAMOFOX_PORT=9377"
        "CAMOFOX_CRASH_REPORT_ENABLED=false"
        "CAMOFOX_PROFILE_DIR=${agentHome}/.camofox/profiles"
        "CAMOFOX_COOKIES_DIR=${agentHome}/.camofox/cookies"
        "CAMOFOX_TRACES_DIR=${agentHome}/.camofox/traces"
        "XDG_CACHE_HOME=${agentHome}/.cache"
        "LD_LIBRARY_PATH=${browserNativeLibraryPath}"
        "PATH=${lib.makeBinPath [ pkgs.camofox-browser pkgs.nodejs_24 pkgs.yt-dlp pkgs.coreutils pkgs.bash ]}"
      ];
      ExecStart = "${lib.getExe pkgs.camofox-browser}";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
