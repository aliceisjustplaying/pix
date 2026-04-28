{ lib, pkgs }:

{
  home = "/home/agent";

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
