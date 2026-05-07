{ pkgs, ... }:

let
  agentHome = "/home/agent";
  workspaceSrc = "/workspace/src";
  tmpl = import ../lib/template.nix;
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
    script = tmpl ../files/host-jobs/pix-rebuild.sh { inherit agentHome workspaceSrc; };
  };

  systemd.services.piclaw-update = hostJob {
    description = "Update Piclaw";
    script = tmpl ../files/host-jobs/piclaw-update.sh { inherit agentHome workspaceSrc; };
  };

  systemd.services.piclaw-update-force = hostJob {
    description = "Force update Piclaw";
    script = tmpl ../files/host-jobs/piclaw-update-force.sh { inherit agentHome workspaceSrc; };
  };

  systemd.services.piclaw-rollback = hostJob {
    description = "Rollback Piclaw";
    script = tmpl ../files/host-jobs/piclaw-rollback.sh { inherit workspaceSrc; };
  };

  systemd.services.piclaw-rollback-force = hostJob {
    description = "Force rollback Piclaw";
    script = tmpl ../files/host-jobs/piclaw-rollback-force.sh { inherit workspaceSrc; };
  };

  systemd.services.piclaw-restart = hostJob {
    description = "Restart Piclaw";
    timeout = "2min";
    script = builtins.readFile ../files/host-jobs/piclaw-restart.sh;
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
