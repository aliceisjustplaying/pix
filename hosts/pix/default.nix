{ lib, modulesPath, ... }:
let
  # Set this to false after Tailscale works and you have verified SSH over the tailnet.
  publicSshBootstrap = false;

  operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+aS2lsR/vsc46amWdsUXGEFuEARJaz3yGAFtVePQuE operator";
  pixKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIASGKGmqo6Inrjo5Vy1z9iS4NKPB6kX8nXiluyjJ8bMe pix.mosphere.at";
in {
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

  networking.hostName = "pix";
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
    allowedTCPPorts = lib.optionals publicSshBootstrap [ 22 ];
    interfaces.tailscale0.allowedTCPPorts = [ 22 80 443 ];
    # tsshd UDP range. Matches Rootshell tssh's default --port 61000-61999.
    interfaces.tailscale0.allowedUDPPortRanges = [ { from = 61000; to = 61999; } ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.agent = import ../../home/agent.nix;
  };

  system.stateVersion = "25.11";
}
