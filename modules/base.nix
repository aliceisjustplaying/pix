{ pkgs, ... }:
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

  services.journald.extraConfig = ''
    SystemMaxUse=500M
  '';

  security.sudo.wheelNeedsPassword = false;

  users.users.agent = {
    isNormalUser = true;
    description = "Piclaw operator";
    home = "/home/agent";
    createHome = true;
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" ];
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
    bat
    fzf
    eza
    delta
    just
    direnv
    shellcheck
    shfmt
    yq-go
    gnumake

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
    gh
    patch
    at
  ];

  # at(1) daemon for deferred job scheduling (used by bsky-boost)
  services.atd.enable = true;

  # cron for bsky-boost scheduled rounds
  services.cron = {
    enable = true;
    systemCronJobs = [
      "CRON_TZ=Europe/London"
      "0 10 * * * agent cd /home/agent/src/bsky-boost && /etc/profiles/per-user/agent/bin/uv run python bsky_boost.py --round 1 >> data/cron.log 2>&1"
      "0 17 * * * agent cd /home/agent/src/bsky-boost && /etc/profiles/per-user/agent/bin/uv run python bsky_boost.py --round 2 >> data/cron.log 2>&1"
      "0 22 * * * agent cd /home/agent/src/bsky-boost && /etc/profiles/per-user/agent/bin/uv run python bsky_boost.py --round 3 >> data/cron.log 2>&1"
      "0  2 * * * agent cd /home/agent/src/bsky-boost && /etc/profiles/per-user/agent/bin/uv run python bsky_boost.py --round 4 >> data/cron.log 2>&1"
    ];
  };

  programs.git.enable = true;
}
