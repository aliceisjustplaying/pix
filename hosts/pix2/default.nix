{ ... }:

{
  imports = [
    ../common
    ../../modules/clickhouse-smoke.nix
    ../../modules/open-webui.nix
  ];

  networking.hostName = "pix2";
}
