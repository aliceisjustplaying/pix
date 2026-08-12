{
  config,
  lib,
  pkgs,
  ...
}:
let
  stateDirectory = "/var/lib/songofsongs";
in
{
  sops.secrets.songofsongs-bsky-username = {
    restartUnits = [ "songofsongs.service" ];
  };
  sops.secrets.songofsongs-bsky-password = {
    restartUnits = [ "songofsongs.service" ];
  };

  users.groups.songofsongs = { };
  users.users.songofsongs = {
    isSystemUser = true;
    group = "songofsongs";
    home = stateDirectory;
  };

  systemd.tmpfiles.rules = [
    "d ${stateDirectory} 0750 songofsongs songofsongs -"
  ];

  systemd.services.songofsongs = {
    description = "Post one Song of Songs line to Bluesky";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "${stateDirectory}/posted.txt";

    serviceConfig = {
      Type = "oneshot";
      User = "songofsongs";
      Group = "songofsongs";
      WorkingDirectory = stateDirectory;
      StateDirectory = "songofsongs";
      LoadCredential = [
        "bsky-username:${config.sops.secrets.songofsongs-bsky-username.path}"
        "bsky-password:${config.sops.secrets.songofsongs-bsky-password.path}"
      ];
      ExecStart = pkgs.writeShellScript "run-songofsongs" ''
        set -euo pipefail
        export BSKY_USERNAME="$(<"$CREDENTIALS_DIRECTORY/bsky-username")"
        export BSKY_PASSWORD="$(<"$CREDENTIALS_DIRECTORY/bsky-password")"
        exec ${lib.getExe pkgs.songofsongs}
      '';

      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ stateDirectory ];
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
      ];
    };
  };

  systemd.timers.songofsongs = {
    description = "Post from Song of Songs every six hours";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 00/6:00:00";
      Persistent = true;
      AccuracySec = "1min";
      Unit = "songofsongs.service";
    };
  };
}
