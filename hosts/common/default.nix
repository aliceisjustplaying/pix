{ modulesPath, ... }:
let
  operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+aS2lsR/vsc46amWdsUXGEFuEARJaz3yGAFtVePQuE operator";
  pixKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIASGKGmqo6Inrjo5Vy1z9iS4NKPB6kX8nXiluyjJ8bMe pix.mosphere.at";
in
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ../../disko/pix.nix
    ../../modules/base.nix
    ../../modules/browser-runtime.nix
    ../../modules/bsky-boost.nix
    ../../modules/host-jobs.nix
    ../../modules/tailscale.nix
    ../../modules/cloudflared.nix
    ../../modules/piclaw.nix
    ../../modules/hermes.nix
    ../../modules/hermes-webui.nix
    ../../modules/plausible.nix
    ../../modules/backup.nix
  ];

  networking.domain = "mosphere.at";
  time.timeZone = "UTC";

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";
    validateSopsFiles = true;
  };

  users.users.agent.openssh.authorizedKeys.keys = [ operatorKey pixKey ];

  services.openssh = {
    enable = true;
    openFirewall = false;
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
    interfaces.tailscale0.allowedTCPPorts = [ 22 80 443 ];
    # tsshd UDP range. Starts at 61001 to avoid overlapping mosh (60000-61000).
    interfaces.tailscale0.allowedUDPPortRanges = [ { from = 61001; to = 61999; } ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.agent = import ../../home/agent.nix;
  };

  system.stateVersion = "25.11";
}
