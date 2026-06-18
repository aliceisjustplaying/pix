{ lib, ... }:

{
  imports = [
    ../common
    ../../modules/clickhouse-smoke.nix
  ];

  networking.hostName = "pix2";

  # Cutover uses direct Caddy DNS, not Cloudflare Tunnel. Keep the package and
  # token around, but do not auto-start the tunnel service on pix2.
  systemd.services = {
    cloudflared.wantedBy = lib.mkForce [ ];
  };
}
