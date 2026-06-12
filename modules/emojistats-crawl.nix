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
  agentService = import ../lib/agent-service.nix { inherit pkgs; lean = true; };
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
    heapMb = lib.mkOption {
      type = lib.types.ints.positive;
      default = 12288;
      description = ''
        V8 old-space cap for the crawl process. Node's default (~4GB) OOMed
        repeatedly at 4096 fetch slots while the loader was backed up; the
        64GB boxes can afford 12GB. The 32GB box (crawl3) sets 8192.
      '';
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
        # on-failure, not "no": it died twice during launch night (ledger
        # contention era) and silently froze the DID universe at 33M of ~45M
        # for nine hours — the crawl ran "fine" against a stale host set and
        # nobody got paged. The cursor checkpoint makes restarts free.
        Restart = "on-failure";
        RestartSec = "60s";
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

    # Digest reconciliation: ledger counts/rkey-digests vs ClickHouse, promotes
    # loaded -> verified (verify.ts). Re-checks already-verified repos too, so
    # cadence is deliberately low — the full acceptance run happens at the end.
    systemd.services.emojistats-verify = {
      description = "emojistats backfill digest verification pass";
      serviceConfig = agentService.serviceDefaults // {
        Type = "oneshot";
        Restart = "no";
        TimeoutStartSec = "infinity";
        WorkingDirectory = backfillDir;
        ExecStartPre = "${pkgs.coreutils}/bin/test -x ${tsx}";
        ExecStart = "${tsx} src/verify.ts";
        EnvironmentFile = config.sops.secrets.emojistats-crawl-env.path;
        Environment = agentService.env { };
      };
    };
    systemd.timers.emojistats-verify = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "00/6:20:00 UTC";
        Persistent = true;
        RandomizedDelaySec = "10m";
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
            # Slots are held through the batched loader's flush wait (up to
            # LOADER_FLUSH_MS), so many are parked, not downloading. After the
            # morel wall, the claim loop learned to skip cooling/full hosts and
            # scan deeper into the skewed tail; with 429s still ambient, the
            # fleet can use a wider global and mushroom cap. Per-host pressure
            # is AIMD now (host-pressure.ts): the static caps are ceilings,
            # 429s converge each host to what it actually tolerates.
            "GLOBAL_CONCURRENCY=4096"
            "PER_HOST_CONCURRENCY_BSKY=96"
            "PER_HOST_CONCURRENCY=16"
            # 50k batches: the 200k default crossed the HTTP upload path's
            # tolerance under load (CANNOT_READ_ALL_DATA mid-body resets).
            "LOADER_BATCH_ROWS=50000"
            "NODE_OPTIONS=--max-old-space-size=${toString cfg.heapMb}"
            "ARCHIVE_SYNC_COMMAND=${syncCommand}"
            # getaddrinfo runs on the libuv threadpool (default 4): retry
            # waves dialing dead PDSes park all four threads in DNS timeouts
            # and every healthy fetch queues behind them before it can even
            # open a socket — observed as fetching=128 with 21 sockets.
            "UV_THREADPOOL_SIZE=64"
          ];
        };
      };
    };
  };
}
