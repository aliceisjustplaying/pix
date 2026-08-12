{ ... }:

{
  imports = [
    ../common
    ../../modules/clickhouse-smoke.nix
    ../../modules/open-webui.nix
  ];

  networking.hostName = "pix2";

  # Historical analytics now live on vps; keep the old instance from returning
  # after a pix2 rebuild.
  pix.plausible.enable = false;

  # tailscale serve binds the tailnet IP on :443; caddy's wildcard :443 bind
  # fails if tailscaled gets there first, so start caddy before tailscaled.
  systemd.services.tailscaled.after = [ "caddy.service" ];
}
