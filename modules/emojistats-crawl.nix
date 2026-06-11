{ config, lib, pkgs, ... }:
# emojistats backfill crawl box (ephemeral; see docs/backfill-runbook.md in the
# emojistats-bsky repo). One shard process per box; the ledger is per-box (full
# enumeration each, complementary CRAWL_SHARD_INDEX). Same live-checkout pattern:
#   sudo -u agent git clone https://github.com/aliceisjustplaying/emojistats-bsky \
#     /workspace/src/emojistats-bsky && cd $_ && bun install
# Enumeration is started manually (systemctl start emojistats-enumerate); the
# crawl service auto-starts on boot and can be started the moment enumeration
# has rows — it claims work as enumeration appends.
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  cfg = config.emojistatsCrawl;
  tsx = "${cfg.checkoutDir}/node_modules/.bin/tsx";
  backfillDir = "${cfg.checkoutDir}/packages/backfill";
  # rclone move: upload + delete local, keeping the crawl box disk flat. The
  # archive sink treats a non-zero exit as fatal (the parquet is the only home
  # of full post text) — the crawl trips rather than accumulating unsynced files.
  syncCommand = "${pkgs.rclone}/bin/rclone --config ${config.sops.secrets.emojistats-rclone-conf.path} move {file} storagebox:emojistats-archive/shard${toString cfg.shardIndex}/";
in
{
  options.emojistatsCrawl = {
    shardIndex = lib.mkOption {
      type = lib.types.ints.unsigned;
      description = "This box's shard (0-based, < shards).";
    };
    shards = lib.mkOption {
      type = lib.types.ints.positive;
      default = 6;
      description = "Total shard count across all crawl boxes.";
    };
    runId = lib.mkOption {
      type = lib.types.str;
      default = "whale-2026";
      description = "BACKFILL_RUN_ID telemetry label, shared across boxes.";
    };
    checkoutDir = lib.mkOption {
      type = lib.types.str;
      default = "/workspace/src/emojistats-bsky";
    };
  };

  config = {
    # CLICKHOUSE_URL points at the serving box over the tailnet; keys documented
    # in SECRETS-CHECKLIST.md.
    sops.secrets.emojistats-crawl-env = { owner = "agent"; };
    sops.secrets.emojistats-rclone-conf = { owner = "agent"; };

    systemd.services.emojistats-enumerate = {
      description = "emojistats PLC directory enumeration (manual start)";
      serviceConfig = agentService.serviceDefaults // {
        Type = "oneshot";
        Restart = "no";
        TimeoutStartSec = "infinity";
        WorkingDirectory = backfillDir;
        ExecStartPre = "${pkgs.coreutils}/bin/test -x ${tsx}";
        ExecStart = "${tsx} src/enumerate.ts";
        EnvironmentFile = config.sops.secrets.emojistats-crawl-env.path;
        Environment = agentService.env {
          extra = [ "PLC_PAGE_DELAY_MS=25" ];
        };
      };
    };

    systemd.services.emojistats-crawl = {
      description = "emojistats backfill crawler (shard ${toString cfg.shardIndex}/${toString cfg.shards})";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = agentService.serviceDefaults // {
        WorkingDirectory = backfillDir;
        ExecStartPre = "${pkgs.coreutils}/bin/test -x ${tsx}";
        ExecStart = "${tsx} src/crawl.ts";
        EnvironmentFile = config.sops.secrets.emojistats-crawl-env.path;
        # EnvironmentFile overrides Environment=, so the secret env can tune any
        # of these per-box without a rebuild.
        Environment = agentService.env {
          extra = [
            "CRAWL_SHARDS=${toString cfg.shards}"
            "CRAWL_SHARD_INDEX=${toString cfg.shardIndex}"
            "SHARD_LABEL=shard${toString cfg.shardIndex}"
            "BACKFILL_RUN_ID=${cfg.runId}"
            "GLOBAL_CONCURRENCY=128"
            "PER_HOST_CONCURRENCY_BSKY=16"
            "ARCHIVE_SYNC_COMMAND=${syncCommand}"
          ];
        };
      };
    };
  };
}
