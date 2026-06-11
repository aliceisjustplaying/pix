# Shared boilerplate for the emojistats hosts (emoji + crawlN) — a trimmed
# hosts/common without the pix2 application modules.
{ ... }:
let
  operatorKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+aS2lsR/vsc46amWdsUXGEFuEARJaz3yGAFtVePQuE operator"
    # Fleet bootstrap key (~/.ssh/backfill) — same key nixos-anywhere installs with.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINW8/PGvo69ULso/5laB2KfFr2PrtJ6rq4+G9nkvWTw4 alice"
  ];
in
{
  imports = [
    ../../modules/base.nix
    ../../modules/tailscale.nix
  ];

  networking.domain = "mosphere.at";
  time.timeZone = "UTC";

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";
    validateSopsFiles = true;
  };

  users.users.agent.openssh.authorizedKeys.keys = operatorKeys;

  # Live checkouts (emojistats services run from /workspace/src/<repo>).
  systemd.tmpfiles.rules = [
    "d /workspace 0755 agent users -"
    "d /workspace/src 0755 agent users -"
  ];

  services.openssh = {
    enable = true;
    # Public 22 for the backfill launch window (key-only, agent user, no root):
    # if first-boot tailscale enrollment fails there is no other way into a
    # freshly-wiped auction box. Flip back to false once the fleet is stable.
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowUsers = [ "agent" ];
      LogLevel = "INFO";
    };
  };

  networking.firewall = {
    enable = true;
    interfaces.tailscale0.allowedTCPPorts = [ 22 ];
    interfaces.tailscale0.allowedUDPPortRanges = [ { from = 61001; to = 61999; } ];
  };

  # The agent home profile is chosen per host: full tooling on emoji, the lean
  # checkout-runner profile on the crawl fleet (hosts/{emoji,crawl} wire it).
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
  };

  system.stateVersion = "25.11";
}
