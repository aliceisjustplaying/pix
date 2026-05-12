{ config, pkgs, ... }:

let
  home = config.home.homeDirectory;
in
{
  systemd.user.services.cli-proxy-api = {
    Unit = {
      Description = "CLIProxyAPI local OAuth LLM proxy";
      After = [ "network-online.target" ];
    };
    Service = {
      ExecStart = "${pkgs.cli-proxy-api}/bin/cli-proxy-api --config ${home}/.cli-proxy-api/config.yaml";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
