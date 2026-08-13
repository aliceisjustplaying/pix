{ modulesPath, ... }:
let
  operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+aS2lsR/vsc46amWdsUXGEFuEARJaz3yGAFtVePQuE operator";
in
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ../../disko/pix.nix
    ../../modules/base.nix
    ../../modules/browser-runtime.nix
    ../../modules/host-jobs.nix
    ../../modules/tailscale.nix
    # Piclaw itself is disabled, but this module still owns the shared agent
    # secrets and workspace layout used by Hermes.
    ../../modules/piclaw.nix
    ../../modules/hermes.nix
    ../../modules/hermes-webui.nix
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

  users.users.agent.openssh.authorizedKeys.keys = [ operatorKey ];

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      AuthenticationMethods = "publickey";
      PubkeyAuthentication = true;
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
