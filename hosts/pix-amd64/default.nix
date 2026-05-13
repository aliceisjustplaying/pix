{ lib, ... }:

{
  imports = [
    ../common
  ];

  networking.hostName = "pix-amd64";

  # Netcup KVM disks normally appear as virtio block devices. Verify with
  # `lsblk -o NAME,SIZE,TYPE,MOUNTPOINT` in rescue before running disko.
  disko.devices.disk.main.device = lib.mkForce "/dev/vda";
}
