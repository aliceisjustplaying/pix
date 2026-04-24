{ config, lib, modulesPath, ... }:
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
    ../../modules/tailscale.nix
    ../../modules/laterminal-compat.nix
    ../../modules/cloudflared.nix
    ../../modules/piclaw.nix
    ../../modules/hermes.nix
    ../../modules/vibes.nix
    ../../modules/vibes-go.nix
    ../../modules/vibes-claude.nix
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
      LogLevel = "DEBUG3";
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = lib.optionals publicSshBootstrap [ 22 ];
    interfaces.tailscale0.allowedTCPPorts = [ 22 8081 8082 8083 ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.agent = import ../../home/agent.nix;
  };

  system.stateVersion = "25.11";
}
