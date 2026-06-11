# Single-disk layout for legacy-BIOS Hetzner auction metal (the i7-6700 class
# does not do UEFI): GPT with a bios_boot partition + GRUB instead of the
# systemd-boot/ESP layout in pix.nix.
# Verify the device on the rescue image with: lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
# (auction boxes vary: /dev/sda for SATA, /dev/nvme0n1 for NVMe; override
# disko.devices.disk.main.device and boot.loader.grub.devices in the host if so).
{ lib, ... }:
{
  # No generated hardware-configuration.nix in this flow, so the initrd must
  # be told about the storage controllers explicitly or stage 1 cannot find
  # the root disk (SATA on crawl2-5, NVMe on crawl0/1, virtio-scsi on emoji
  # via the qemu-guest profile).
  boot.initrd.availableKernelModules = [ "ahci" "nvme" "xhci_pci" "ehci_pci" "usbhid" "sd_mod" ];

  # base.nix configures GRUB for UEFI (pix2/cloud); metal auction boxes are
  # legacy BIOS, so force the relevant knobs back.
  boot.loader.grub = {
    enable = true;
    efiSupport = lib.mkForce false;
    efiInstallAsRemovable = lib.mkForce false;
    device = lib.mkForce "nodev";
    devices = lib.mkDefault [ "/dev/sda" ];
  };

  disko.devices = {
    disk.main = {
      type = "disk";
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            type = "EF02";
          };

          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "noatime" ];
            };
          };
        };
      };
    };
  };
}
