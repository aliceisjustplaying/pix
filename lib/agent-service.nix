{ lib, pkgs }:

{
  home = "/home/agent";

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

  path = extraPackages:
    lib.makeBinPath ([
      pkgs.bash
      pkgs.coreutils
      pkgs.findutils
      pkgs.git
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.openssh
      pkgs.procps
      pkgs.sqlite
      pkgs.which
    ] ++ extraPackages);
}
