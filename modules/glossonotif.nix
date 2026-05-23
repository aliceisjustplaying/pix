{ pkgs, ... }:
{
  systemd.services.glossonotif = {
    description = "Glosso push notification gateway";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/home/agent/glossonotif";
      EnvironmentFile = "/home/agent/glossonotif/.env";
      ExecStart = "${pkgs.nodejs_24}/bin/node src/server.js";
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };

  services.caddy.virtualHosts."glosson.mosphere.at".extraConfig = ''
    encode zstd gzip
    reverse_proxy 127.0.0.1:3099
  '';
}
