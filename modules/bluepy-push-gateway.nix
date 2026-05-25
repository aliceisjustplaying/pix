{ pkgs, ... }:
{
  systemd.services.bluepy-push-gateway-dev = {
    description = "Bluepy Push Gateway dev";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/home/agent/bluepy-push-gateway-dev";
      EnvironmentFile = "/home/agent/bluepy-push-gateway-dev/.env";
      ExecStart = "${pkgs.nodejs_24}/bin/node dist/server.js";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };

  services.caddy.virtualHosts."dev.notification-gateway.bluepy.social".extraConfig = ''
    encode zstd gzip

    @did path /.well-known/did.json
    header @did Content-Type application/json
    respond @did `{"@context":["https://www.w3.org/ns/did/v1"],"id":"did:web:dev.notification-gateway.bluepy.social","service":[]}` 200

    reverse_proxy 127.0.0.1:8790
  '';
}
