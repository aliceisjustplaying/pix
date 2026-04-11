{ lib, ... }:
{
  disko.devices = {
    disk.main = {
      type = "disk";
      # Verify this on the temporary Hetzner image with:
      #   lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
      # and change it if needed (common alternatives are /dev/vda or /dev/nvme0n1).
      device = lib.mkDefault "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
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
