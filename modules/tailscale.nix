{ config, lib, ... }:
{
  options.tailscaleTag = lib.mkOption {
    type = lib.types.str;
    default = "tag:pix";
    description = "ACL tag the auth key is allowed to apply (must match the key).";
  };

  config = {
  sops.secrets.tailscale-auth-key = {
    owner = "root";
    group = "root";
    mode = "0400";
    restartUnits = [ "tailscaled-autoconnect.service" ];
  };

  services.tailscale = {
    enable = true;
    openFirewall = true;
    authKeyFile = config.sops.secrets.tailscale-auth-key.path;
    extraUpFlags = [
      "--advertise-tags=${config.tailscaleTag}"
      "--accept-dns=false"
    ];
  };

  # Avoid long boot hangs if the auth key is wrong or approval is pending.
  systemd.services.tailscaled-autoconnect.serviceConfig.TimeoutStartSec = "30s";
  };
}
