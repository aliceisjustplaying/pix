{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  monitoringPkgs = import inputs.nixpkgs-unstable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };

  prometheusDatasource = "Prometheus";

  timeseries =
    { title
    , expr
    , unit ? "short"
    , span ? 12
    , height ? 8
    }:
    {
      inherit title;
      type = "timeseries";
      gridPos = {
        h = height;
        w = span;
        x = 0;
        y = 0;
      };
      datasource = prometheusDatasource;
      targets = [
        {
          refId = "A";
          datasource = prometheusDatasource;
          inherit expr;
        }
      ];
      fieldConfig.defaults.unit = unit;
      options.legend = {
        displayMode = "table";
        placement = "bottom";
        showLegend = true;
      };
    };

  stat =
    { title
    , expr
    , unit ? "short"
    , span ? 6
    , height ? 4
    }:
    {
      inherit title;
      type = "stat";
      gridPos = {
        h = height;
        w = span;
        x = 0;
        y = 0;
      };
      datasource = prometheusDatasource;
      targets = [
        {
          refId = "A";
          datasource = prometheusDatasource;
          inherit expr;
        }
      ];
      fieldConfig.defaults.unit = unit;
      options.reduceOptions.calcs = [ "lastNotNull" ];
    };

  mkDashboard =
    { uid
    , title
    , panels
    }:
    builtins.toJSON {
      inherit uid title panels;
      schemaVersion = 39;
      version = 1;
      refresh = "10s";
      tags = [
        "pix2"
        "provisioned"
      ];
      time = {
        from = "now-6h";
        to = "now";
      };
    };

  dashboardDir = pkgs.linkFarm "grafana-dashboards" [
    {
      name = "pix2-host.json";
      path = pkgs.writeText "pix2-host.json" (mkDashboard {
        uid = "pix2-host";
        title = "Pix2 Host";
        panels = [
          (stat {
            title = "CPU busy";
            expr = ''100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
            unit = "percent";
          })
          (stat {
            title = "Memory used";
            expr = ''(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100'';
            unit = "percent";
          })
          (timeseries {
            title = "Load average";
            expr = "node_load1";
          })
          (timeseries {
            title = "Filesystem available";
            expr = ''node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs"}'';
            unit = "bytes";
          })
          (timeseries {
            title = "Network receive";
            expr = ''rate(node_network_receive_bytes_total{device!="lo"}[5m])'';
            unit = "Bps";
          })
          (timeseries {
            title = "Network transmit";
            expr = ''rate(node_network_transmit_bytes_total{device!="lo"}[5m])'';
            unit = "Bps";
          })
        ];
      });
    }
    {
      name = "pix2-services.json";
      path = pkgs.writeText "pix2-services.json" (mkDashboard {
        uid = "pix2-services";
        title = "Pix2 Services";
        panels = [
          (stat {
            title = "Failed systemd units";
            expr = ''sum(systemd_units{state="failed"})'';
          })
          (timeseries {
            title = "Unit states";
            expr = ''sum by (name, state) (systemd_units{name=~"prometheus.*|grafana.*|caddy.*|clickhouse.*|postgresql.*|plausible.*"})'';
          })
          (timeseries {
            title = "Caddy requests";
            expr = ''sum by (code) (rate(caddy_http_requests_total[5m]))'';
          })
          (timeseries {
            title = "Caddy admin requests";
            expr = ''sum by (code) (rate(caddy_admin_http_requests_total[5m]))'';
          })
        ];
      });
    }
    {
      name = "pix2-databases.json";
      path = pkgs.writeText "pix2-databases.json" (mkDashboard {
        uid = "pix2-databases";
        title = "Pix2 Databases";
        panels = [
          (stat {
            title = "Postgres up";
            expr = "pg_up";
          })
          (timeseries {
            title = "Postgres connections";
            expr = ''sum by (datname, state) (pg_stat_activity_count)'';
          })
          (timeseries {
            title = "Postgres transaction rate";
            expr = ''sum by (datname) (rate(pg_stat_database_xact_commit[5m]) + rate(pg_stat_database_xact_rollback[5m]))'';
          })
          (timeseries {
            title = "ClickHouse queries";
            expr = "rate(ClickHouseProfileEvents_Query[5m])";
          })
          (timeseries {
            title = "ClickHouse selected rows";
            expr = "rate(ClickHouseProfileEvents_SelectedRows[5m])";
          })
          (timeseries {
            title = "ClickHouse memory";
            expr = "ClickHouseMetrics_MemoryTracking";
            unit = "bytes";
          })
        ];
      });
    }
  ];
in
{
  system.activationScripts.grafana-admin-password.text = ''
    install -d -m 0750 -o grafana -g grafana /var/lib/grafana

    if [ ! -s /var/lib/grafana/admin-password ]; then
      ${pkgs.openssl}/bin/openssl rand -base64 32 > /var/lib/grafana/admin-password
    fi

    chown root:grafana /var/lib/grafana/admin-password
    chmod 0640 /var/lib/grafana/admin-password
  '';

  services.prometheus = {
    enable = true;
    package = monitoringPkgs.prometheus;
    listenAddress = "127.0.0.1";
    retentionTime = "30d";

    globalConfig = {
      scrape_interval = "5s";
      evaluation_interval = "5s";
    };

    scrapeConfigs = [
      {
        job_name = "prometheus";
        static_configs = [
          { targets = [ "127.0.0.1:9090" ]; }
        ];
      }
      {
        job_name = "node";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ "127.0.0.1:9100" ]; }
        ];
      }
      {
        job_name = "systemd";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ "127.0.0.1:9558" ]; }
        ];
      }
      {
        job_name = "caddy";
        scrape_interval = "5s";
        metrics_path = "/metrics";
        static_configs = [
          { targets = [ "127.0.0.1:2019" ]; }
        ];
      }
      {
        job_name = "clickhouse";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ "127.0.0.1:9363" ]; }
        ];
      }
      {
        job_name = "postgres";
        scrape_interval = "5s";
        static_configs = [
          { targets = [ "127.0.0.1:9187" ]; }
        ];
      }
    ];

    exporters = {
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        enabledCollectors = [ "systemd" ];
      };

      systemd = {
        enable = true;
        listenAddress = "127.0.0.1";
      };

      postgres = {
        enable = true;
        listenAddress = "127.0.0.1";
        runAsLocalSuperUser = true;
      };
    };
  };

  systemd.services.prometheus-node-exporter.serviceConfig.ExecStart = lib.mkForce ''
    ${monitoringPkgs.prometheus-node-exporter}/bin/node_exporter \
      --collector.systemd \
      --web.listen-address 127.0.0.1:9100
  '';

  systemd.services.prometheus-systemd-exporter.serviceConfig.ExecStart = lib.mkForce ''
    ${monitoringPkgs.prometheus-systemd-exporter}/bin/systemd_exporter \
      --web.listen-address 127.0.0.1:9558
  '';

  systemd.services.prometheus-postgres-exporter.serviceConfig.ExecStart = lib.mkForce ''
    ${monitoringPkgs.prometheus-postgres-exporter}/bin/postgres_exporter \
      --web.listen-address 127.0.0.1:9187 \
      --web.telemetry-path /metrics
  '';

  services.caddy.globalConfig = lib.mkAfter ''
    metrics
  '';

  systemd.services.clickhouse.restartTriggers = [
    config.environment.etc."clickhouse-server/config.d/200-nixos-module-extra-config.xml".source
  ];

  services.grafana = {
    enable = true;
    package = monitoringPkgs.grafana;

    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
        domain = "grafana.pix2.mosphere.at";
        root_url = "https://grafana.pix2.mosphere.at/";
      };

      security = {
        admin_user = "alice";
        admin_password = "$__file{/var/lib/grafana/admin-password}";
        cookie_secure = true;
      };

      "auth.anonymous".enabled = false;

      users = {
        allow_sign_up = false;
        auto_assign_org = false;
      };
    };

    provision.datasources.settings = {
      apiVersion = 1;
      prune = true;
      datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          access = "proxy";
          url = "http://127.0.0.1:9090";
          isDefault = true;
          editable = false;
        }
      ];
    };

    provision.dashboards.settings = {
      apiVersion = 1;
      providers = [
        {
          name = "pix2";
          type = "file";
          disableDeletion = false;
          editable = false;
          options.path = dashboardDir;
        }
      ];
    };
  };

  services.caddy.virtualHosts."grafana.pix2.mosphere.at".extraConfig = ''
    encode zstd gzip
    reverse_proxy 127.0.0.1:3000
  '';
}
