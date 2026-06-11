# emojistats serving box — Hetzner Cloud CX33 (4 vCPU Intel / 8 GB / 80 GB).
# Hetzner Cloud x86 boots SeaBIOS (no /sys/firmware/efi on the stock Debian
# image), so this uses the legacy-BIOS GPT layout from disko/metal.nix — the
# ESP-only pix.nix layout would install fine and then fail to boot.
{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ../server-common
    ../../disko/metal.nix
    ../../modules/emojistats.nix
  ];

  networking.hostName = "emoji";

  home-manager.users.agent = import ../../home/agent-lean.nix;
}
