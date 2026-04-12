{ config, pkgs, ... }:
let
  accountId = "b752c979e541327de3e87e52f0906aa1";
in {
  sops.secrets.restic-password = {
    restartUnits = [ "restic-backups-r2.service" ];
  };

  sops.secrets.r2-access-key-id = { };
  sops.secrets.r2-secret-access-key = { };

  sops.templates.restic-r2-env = {
    content = ''
      AWS_ACCESS_KEY_ID=${config.sops.placeholder.r2-access-key-id}
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.r2-secret-access-key}
    '';
  };

  services.restic.backups.r2 = {
    initialize = true;
    repository = "s3:https://${accountId}.r2.cloudflarestorage.com/pix-backup";
    passwordFile = config.sops.secrets.restic-password.path;
    environmentFile = config.sops.templates.restic-r2-env.path;

    paths = [
      "/workspace"
    ];

    exclude = [
      "/workspace/.cache"
      "/workspace/src/piclaw-live"
      "/workspace/src/piclaw-live.previous"
      "/workspace/src/piclaw-fork"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 3"
    ];
  };
}
