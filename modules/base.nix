{ pkgs, ... }:
let
  wranglerLatest = pkgs.writeShellApplication {
    name = "wrangler";
    runtimeInputs = [ pkgs.nodejs ];
    text = builtins.readFile ../files/bin/wrangler.sh;
  };
in
{
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    auto-optimise-store = true;
    trusted-users = [ "root" "@wheel" ];
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.optimise.automatic = true;

  boot.loader = {
    efi.canTouchEfiVariables = false;
    grub = {
      enable = true;
      efiSupport = true;
      efiInstallAsRemovable = true;
      device = "nodev";
    };
    timeout = 1;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.blacklistedKernelModules = [
    "esp4"
    "esp6"
    "ipcomp4"
    "ipcomp6"
    "rxrpc"
  ];
  boot.extraModprobeConfig = ''
    install esp4 /bin/false
    install esp6 /bin/false
    install ipcomp4 /bin/false
    install ipcomp6 /bin/false
    install rxrpc /bin/false
  '';
  boot.tmp.cleanOnBoot = true;

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 8192;
    }
  ];

  zramSwap = {
    enable = true;
    memoryPercent = 100;
    algorithm = "zstd";
  };

  i18n.defaultLocale = "en_US.UTF-8";
  services.qemuGuest.enable = true;

  services.journald.extraConfig = builtins.readFile ../files/journald/journald.conf;

  security.sudo.wheelNeedsPassword = false;

  users.users.agent = {
    isNormalUser = true;
    description = "Piclaw operator";
    home = "/home/agent";
    createHome = true;
    shell = pkgs.bashInteractive;
    extraGroups = [
      "wheel"
      "systemd-journal"
    ];
  };

  environment.enableAllTerminfo = true;

  environment.systemPackages = with pkgs; [
    curl
    wget
    vim
    git
    jq
    ripgrep
    fd
    dnsutils
    wranglerLatest
    xdg-utils
    bat
    fzf
    eza
    delta
    fastfetch
    just
    direnv
    shellcheck
    shfmt
    yq-go
    gnumake
    go_1_26
    zig

    # Rust toolchain
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer

    tree
    tmux
    htop
    btop
    unzip
    zip
    rsync
    age
    sops
    ssh-to-age
    cloudflared
    bubblewrap
    chromium
    gh
    ghstack
    git-crypt
    patch
    at


  ];

  # mosh: roaming, low-latency SSH replacement.
  # Enabling the module installs the client/server and opens
  # UDP 60000-61000 in the firewall.
  programs.mosh.enable = true;

  programs.git.enable = true;
}
