# emojistats crawl boxes — ephemeral Hetzner auction metal (i7-6700 class,
# legacy BIOS boot, hence disko/metal.nix + GRUB). Instantiated per shard from
# flake.nix: crawl0..crawl5.
{ shardIndex, diskDevice ? "/dev/sda" }:
{ modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/scan/not-detected.nix"
    ../server-common
    ../../disko/metal.nix
    ../../modules/emojistats-crawl.nix
  ];

  networking.hostName = "crawl${toString shardIndex}";

  emojistatsCrawl.shardIndex = shardIndex;

  # Mixed auction hardware (set per shard in flake.nix). Every box has a second
  # identical disk that stays unformatted — spool headroom if ever needed.
  # disko derives boot.loader.grub.devices from the EF02-carrying disk, so this
  # one assignment is the whole story (listing devices here too duplicates it).
  disko.devices.disk.main.device = diskDevice;
}
