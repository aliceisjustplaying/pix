# emojistats serving box — Hetzner Cloud CPX32 (4 vCPU AMD / 8 GB / 160 GB);
# CX33 was out of stock at deploy time. The extra disk is pure headroom.
{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ../server-common
    ../../disko/pix.nix
    ../../modules/emojistats.nix
  ];

  networking.hostName = "emoji";
}
