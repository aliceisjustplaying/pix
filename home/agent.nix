{ ... }:

{
  imports = [
    ./agent/packages.nix
    ./agent/files.nix
    ./agent/cli-proxy.nix
    ./agent/shell.nix
    ./agent/git-ssh.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;
}
