# emojistats crawl boxes — ephemeral Hetzner auction metal (i7-6700 class,
# legacy BIOS boot, hence disko/metal.nix + GRUB). Instantiated per shard from
# flake.nix: crawl0..crawl5.
{ shardIndex }:
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
}
