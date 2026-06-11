# Shared boilerplate for the emojistats hosts (emoji + crawlN) — a trimmed
# hosts/common without the pix2 application modules.
{ ... }:
let
  operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+aS2lsR/vsc46amWdsUXGEFuEARJaz3yGAFtVePQuE operator";
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

  users.users.agent.openssh.authorizedKeys.keys = [ operatorKey ];

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
    interfaces.tailscale0.allowedTCPPorts = [ 22 ];
    interfaces.tailscale0.allowedUDPPortRanges = [ { from = 61001; to = 61999; } ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    users.agent = import ../../home/agent.nix;
  };

  system.stateVersion = "25.11";
}
