{ modulesPath, pkgs, ... }:
let
  operatorKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF+aS2lsR/vsc46amWdsUXGEFuEARJaz3yGAFtVePQuE operator";
in
{
  imports = [
    "${modulesPath}/profiles/qemu-guest.nix"
    ../../disko/vps.nix
    ../../modules/plausible.nix
    ../../modules/songofsongs.nix
  ];

  networking = {
    hostName = "vps";
    domain = "bsky.sh";
    useDHCP = true;
    firewall = {
      enable = true;
      allowedTCPPorts = [
        22
        80
        443
      ];
    };
  };

  time.timeZone = "UTC";

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  boot.loader = {
    efi.canTouchEfiVariables = false;
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 4096;
    }
  ];
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    algorithm = "zstd";
  };

  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    defaultSopsFormat = "yaml";
    age.keyFile = "/var/lib/sops-nix/key.txt";
    validateSopsFiles = true;
  };

  security.sudo.wheelNeedsPassword = false;
  users.users.agent = {
    isNormalUser = true;
    description = "VPS operator";
    home = "/home/agent";
    createHome = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ operatorKey ];
  };

  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      X11Forwarding = false;
      AllowUsers = [ "agent" ];
    };
  };

  pix.plausible.servePixProxy = false;
  services.caddy.virtualHosts."plausible.bsky.sh".extraConfig = ''
    redir https://p.mosphere.at{uri} permanent
  '';

  environment.systemPackages = with pkgs; [
    curl
    git
    jq
    vim
  ];

  system.stateVersion = "26.05";
}
