{ inputs, pkgs, ... }:
let
  gib = size: size * 1024 * 1024 * 1024;
  kernelPkgs = import inputs.kernel-nixpkgs {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
  wranglerLatest = pkgs.writeShellApplication {
    name = "wrangler";
    runtimeInputs = [ pkgs.nodejs ];
    text = builtins.readFile ../files/bin/wrangler.sh;
  };
in
{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    min-free = gib 10;
    max-free = gib 20;
    trusted-users = [
      "root"
      "@wheel"
    ];
  };
  nix.nixPath = [ "nixpkgs=flake:nixpkgs" ];

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 7d";
  };

  systemd.services.nix-generation-prune = {
    description = "Keep only the newest four NixOS system generations";
    path = with pkgs; [
      coreutils
      gawk
      nix
    ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail

      mapfile -t generations < <(
        nix-env --profile /nix/var/nix/profiles/system --list-generations \
          | awk '{ print $1 }'
      )
      delete_count=$((''${#generations[@]} - 4))

      if (( delete_count <= 0 )); then
        echo "''${#generations[@]} system generations present; nothing to prune"
        exit 0
      fi

      echo "pruning $delete_count old system generations"
      nix-env --profile /nix/var/nix/profiles/system --delete-generations \
        "''${generations[@]:0:delete_count}"
    '';
  };

  systemd.services.nix-gc = {
    requires = [ "nix-generation-prune.service" ];
    after = [ "nix-generation-prune.service" ];
  };

  nix.optimise.automatic = true;

  systemd.services.nix-disk-guard = {
    description = "Run Nix garbage collection when root disk space is low";
    path = with pkgs; [
      coreutils
      gawk
      nix
    ];
    serviceConfig.Type = "oneshot";
    # `nix-store --optimise` is intentionally absent here: `nix.optimise.automatic`
    # already runs it on its own timer. We only want extra GC pressure when the
    # disk is actually filling up, not extra hardlink churn.
    script = ''
      set -euo pipefail

      min_free=${toString (gib 12)}
      available="$(df -PB1 / | awk 'NR == 2 { print $4 }')"

      if [ "$available" -ge "$min_free" ]; then
        echo "root has $available bytes free; no cleanup needed"
        exit 0
      fi

      echo "root has only $available bytes free; running Nix garbage collection"
      nix-collect-garbage --delete-older-than 7d

      available_after="$(df -PB1 / | awk 'NR == 2 { print $4 }')"
      if [ "$available_after" -lt "$min_free" ]; then
        echo "root still has only $available_after bytes free after cleanup (floor: $min_free)" >&2
        exit 1
      fi

      echo "root has $available_after bytes free after cleanup"
    '';
  };

  systemd.timers.nix-disk-guard = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "15min";
      OnUnitActiveSec = "30min";
      AccuracySec = "5min";
      Persistent = true;
    };
  };

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

  boot.kernelPackages = kernelPkgs.linuxPackages_latest;
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

  systemd.coredump.settings.Coredump = {
    Storage = "none";
    ProcessSizeMax = 0;
    ExternalSizeMax = 0;
    JournalSizeMax = 0;
  };

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
    nixfmt-rfc-style
    gnumake
    gcc
    go_1_26
    zig

    rust-nightly
    rust-nightly-llvm-tools
    cargo-nextest
    cargo-deny
    cargo-audit
    cargo-machete
    cargo-llvm-cov
    wasm-pack
    wasm-bindgen-cli

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
    libopus
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
