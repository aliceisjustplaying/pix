{ config, lib, pkgs, ... }:
# emojistats serving stack (plan 0001 in the emojistats-bsky repo): ClickHouse +
# ingest worker + Socket.IO API + public backfill dashboard + aggregate-rebuild
# timers. App code runs from a live checkout (hermes pattern):
#   sudo -u agent git clone https://github.com/aliceisjustplaying/emojistats-bsky \
#     /workspace/src/emojistats-bsky && cd $_ && bun install
#   cd packages/dashboard && bun run build   # rebuild after every dashboard pull
# then `bun run db:migrate` once in packages/ingest (needs emojistats-env secret).
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; lean = true; };
  cfg = config.emojistats;
  tsx = "${cfg.checkoutDir}/node_modules/.bin/tsx";

  mkAppService = { description, workdir, execStart, memoryMax, extraEnv ? [ ], extraConfig ? { } }: {
    inherit description;
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "clickhouse.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = agentService.serviceDefaults // {
      WorkingDirectory = workdir;
      ExecStartPre = "${pkgs.coreutils}/bin/test -x ${tsx}";
      ExecStart = execStart;
      EnvironmentFile = config.sops.secrets.emojistats-env.path;
      Environment = agentService.env { extra = extraEnv; };
      MemoryMax = memoryMax;
    } // extraConfig;
  };
in
{
  options.emojistats = {
    checkoutDir = lib.mkOption {
      type = lib.types.str;
      default = "/workspace/src/emojistats-bsky";
      description = "Live git checkout the services run from.";
    };
    dashboardHost = lib.mkOption {
      type = lib.types.str;
      default = "backfill.mosphere.at";
      description = "Public vhost for the shareable backfill dashboard.";
    };
  };

  config = {
    # Opaque env file consumed by every service; expected keys documented in
    # SECRETS-CHECKLIST.md (CLICKHOUSE_* credentials, ORIGINS, ports).
    sops.secrets.emojistats-env = { owner = "agent"; };

    # users.d drop-in defining the `emojistats` ClickHouse user
    # (password_sha256_hex; see SECRETS-CHECKLIST.md for the template).
    sops.secrets."emojistats-clickhouse-users.xml" = {
      owner = "clickhouse";
      group = "clickhouse";
      path = "/etc/clickhouse-server/users.d/emojistats.xml";
      restartUnits = [ "clickhouse.service" ];
    };

    services.clickhouse.enable = true;
    # Sized for the CX33 (8 GB): CH gets 5 GB hard, trimmed mark cache. Listens
    # on all interfaces but the firewall only opens 8123 on the tailnet — that
    # is how the crawl boxes reach it during the backfill.
    services.clickhouse.extraServerConfig = ''
      <clickhouse>
        <max_server_memory_usage>5368709120</max_server_memory_usage>
        <mark_cache_size>536870912</mark_cache_size>
        <listen_host>0.0.0.0</listen_host>
        <prometheus>
          <endpoint>/metrics</endpoint>
          <port>9363</port>
          <metrics>true</metrics>
          <events>true</events>
        </prometheus>
      </clickhouse>
    '';

    # The live worker spools full post text to parquet exactly like the crawl
    # boxes do — its archive is the only durable home of the live tail's
    # non-emoji text, so it ships to the same Storage Box (live/ prefix).
    # Without ARCHIVE_SYNC_COMMAND finalized files would pile up on the 80 GB
    # disk forever; the sink's startup sweep re-ships any stranded file.
    sops.secrets.emojistats-rclone-conf = { owner = "agent"; };
    systemd.services.emojistats-ingest = mkAppService {
      description = "emojistats live Jetstream ingest worker";
      workdir = "${cfg.checkoutDir}/packages/ingest";
      execStart = "${tsx} src/index.ts";
      memoryMax = "1G";
      extraEnv = [
        "ARCHIVE_DIR=/var/lib/emojistats/archive"
        "ARCHIVE_SYNC_COMMAND=${pkgs.rclone}/bin/rclone --config ${config.sops.secrets.emojistats-rclone-conf.path} move {file} storagebox:emojistats-archive/live/"
      ];
      extraConfig = {
        StateDirectory = "emojistats/archive";
      };
    };

    systemd.services.emojistats-api = mkAppService {
      description = "emojistats Socket.IO API (ClickHouse-backed)";
      workdir = "${cfg.checkoutDir}/packages/backend";
      execStart = "${tsx} src/index.ts";
      memoryMax = "512M";
    };

    systemd.services.emojistats-dashboard = mkAppService {
      description = "emojistats ops + backfill dashboard";
      workdir = "${cfg.checkoutDir}/packages/dashboard";
      execStart = "${pkgs.bun}/bin/bun run dist/server/server.js";
      memoryMax = "512M";
      extraEnv = [ "PORT=3105" ];
      extraConfig = {
        # Built artifact must exist (bun run build after each dashboard pull).
        ExecStartPre = "${pkgs.coreutils}/bin/test -f ${cfg.checkoutDir}/packages/dashboard/dist/server/server.js";
      };
    };

    # Aggregates are disposable caches over raw `posts`; these timers are the
    # self-heal loop (and the weekly exact rebuild) from plan 0001.
    systemd.services.emojistats-rebuild-recent = {
      description = "emojistats aggregate self-heal (last 7 days)";
      serviceConfig = agentService.serviceDefaults // {
        Type = "oneshot";
        Restart = "no";
        WorkingDirectory = "${cfg.checkoutDir}/packages/ingest";
        ExecStart = "${tsx} src/clickhouse/rebuild.ts --recent 7";
        EnvironmentFile = config.sops.secrets.emojistats-env.path;
        Environment = agentService.env { };
      };
    };
    systemd.timers.emojistats-rebuild-recent = {
      wantedBy = [ "timers.target" ];
      timerConfig = { OnCalendar = "*-*-* 03:40:00 UTC"; Persistent = true; };
    };

    systemd.services.emojistats-rebuild-full = {
      description = "emojistats full aggregate rebuild (shadow + exchange)";
      serviceConfig = agentService.serviceDefaults // {
        Type = "oneshot";
        Restart = "no";
        WorkingDirectory = "${cfg.checkoutDir}/packages/ingest";
        ExecStart = "${tsx} src/clickhouse/rebuild.ts --full";
        EnvironmentFile = config.sops.secrets.emojistats-env.path;
        Environment = agentService.env { };
      };
    };
    systemd.timers.emojistats-rebuild-full = {
      wantedBy = [ "timers.target" ];
      timerConfig = { OnCalendar = "Sun *-*-* 04:30:00 UTC"; Persistent = true; };
    };

    services.caddy = {
      enable = true;
      email = "aliceisjustplaying@gmail.com";
      globalConfig = ''
        acme_ca https://acme.zerossl.com/v2/DV90
      '';
      # The built TanStack Start node server only handles routes — client
      # assets are plain files in dist/client that something must serve.
      virtualHosts.${cfg.dashboardHost}.extraConfig = ''
        root * ${cfg.checkoutDir}/packages/dashboard/dist/client
        @static file
        handle @static {
          file_server
        }
        handle {
          reverse_proxy 127.0.0.1:3105
        }
      '';
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8123 ];
  };
}
