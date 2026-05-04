{ pkgs, ... }:

let
  agentHome = "/home/agent";
  workspaceSrc = "/workspace/src";
  hostPath = with pkgs; [
    bash
    coreutils
    git
    nix
    nixos-rebuild
    openssh
    systemd
    util-linux
  ];
  hostJob =
    {
      description,
      script,
      timeout ? "15min",
    }:
    {
      inherit description;
      path = hostPath;
      serviceConfig = {
        Type = "oneshot";
        User = "root";
        TimeoutStartSec = timeout;
        ExecStart = pkgs.writeShellScript description script;
      };
    };
in
{
  systemd.services.pix-rebuild = hostJob {
    description = "Rebuild Pix NixOS configuration";
    script = ''
      set -euo pipefail
      cd ${workspaceSrc}/pix
      runuser -u agent -- env HOME=${agentHome} git pull --ff-only
      nixos-rebuild switch --flake path:${agentHome}/workspace/src/pix#pix
    '';
  };

  systemd.services.piclaw-update = hostJob {
    description = "Update Piclaw";
    script = ''
      set -euo pipefail
      cd ${workspaceSrc}/piclaw-customizations
      runuser -u agent -- env HOME=${agentHome} git pull --ff-only
      ./scripts/piclaw-update-host.sh
    '';
  };

  systemd.services.piclaw-update-force = hostJob {
    description = "Force update Piclaw";
    script = ''
      set -euo pipefail
      cd ${workspaceSrc}/piclaw-customizations
      runuser -u agent -- env HOME=${agentHome} git pull --ff-only
      ./scripts/piclaw-update-host.sh --force
    '';
  };

  systemd.services.piclaw-rollback = hostJob {
    description = "Rollback Piclaw";
    script = ''
      set -euo pipefail
      cd ${workspaceSrc}/piclaw-customizations
      ./scripts/piclaw-rollback-host.sh
    '';
  };

  systemd.services.piclaw-rollback-force = hostJob {
    description = "Force rollback Piclaw";
    script = ''
      set -euo pipefail
      cd ${workspaceSrc}/piclaw-customizations
      ./scripts/piclaw-rollback-host.sh --force
    '';
  };

  systemd.services.piclaw-restart = hostJob {
    description = "Restart Piclaw";
    timeout = "2min";
    script = ''
      set -euo pipefail
      sleep 2
      systemctl restart piclaw.service
    '';
  };

  security.sudo.extraRules = [
    {
      users = [ "agent" ];
      commands = [
        {
          command = "/run/current-system/sw/bin/systemctl start --no-block pix-rebuild.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start --no-block piclaw-update.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start --no-block piclaw-update-force.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start --no-block piclaw-rollback.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start --no-block piclaw-rollback-force.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start --no-block piclaw-restart.service";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/run/current-system/sw/bin/systemctl start --no-block restic-backups-r2.service";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
