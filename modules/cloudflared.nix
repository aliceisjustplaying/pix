{ config, pkgs, ... }:
{
  sops.secrets.cloudflared-tunnel-token = {
    restartUnits = [ "cloudflared.service" ];
  };

  systemd.services.cloudflared = {
    description = "Cloudflare Tunnel";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "notify";
      TimeoutStartSec = "0";
      Restart = "on-failure";
      RestartSec = "5s";
      ExecStart = "${pkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate run --token-file ${config.sops.secrets.cloudflared-tunnel-token.path}";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      StateDirectory = "cloudflared";
      CacheDirectory = "cloudflared";
    };
  };
}
