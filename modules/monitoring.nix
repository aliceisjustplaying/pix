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

  communityDashboard =
    { id
    , name
    , hash
    }:
    pkgs.runCommand "${name}.json" {
      nativeBuildInputs = [ pkgs.jq ];
      src = pkgs.fetchurl {
        url = "https://grafana.com/api/dashboards/${toString id}/revisions/latest/download";
        inherit hash;
      };
    } ''
      jq '
        def normalize:
          if type == "object" then
            if (.datasource? | type) == "object" and .datasource.type == "prometheus" then
              .datasource = "Prometheus"
            elif (.datasource? | type) == "string" and (.datasource | test("\\$\\{.*[Pp]rometheus.*\\}|\\$\\{.*PROMETHEUS.*\\}")) then
              .datasource = "Prometheus"
            else
              .
            end
          else
            .
          end;

        walk(normalize)
        | del(.__inputs)
        | del(.__requires)
        | .id = null
        | .refresh = "10s"
        | (.templating.list // []) |= map(
            if .type == "datasource" and .query == "prometheus" then
              .current = {"text": "Prometheus", "value": "Prometheus", "selected": true}
            else
              .
            end
          )
      ' "$src" > "$out"
    '';

  dashboardDir = pkgs.linkFarm "grafana-dashboards" [
    {
      name = "node-exporter-full.json";
      path = communityDashboard {
        id = 1860;
        name = "node-exporter-full";
        hash = "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
      };
    }
    {
      name = "systemd-exporter.json";
      path = communityDashboard {
        id = 22872;
        name = "systemd-exporter";
        hash = "sha256-ZlvD6Gt5dJsv2ud4f0t1AuAIMImL9I9zxoE0Rx9yvzM=";
      };
    }
    {
      name = "postgresql-database.json";
      path = communityDashboard {
        id = 9628;
        name = "postgresql-database";
        hash = "sha256-UhusNAZbyt7fJV/DhFUK4FKOmnTpG0R15YO2r+nDnMc=";
      };
    }
    {
      name = "clickhouse.json";
      path = communityDashboard {
        id = 14192;
        name = "clickhouse";
        hash = "sha256-daBB/MKnjj8rFBlCta0iOAHiE4+xgkQQ4Pb5LQBADN8=";
      };
    }
    {
      name = "caddy-standalone-reverse-proxy.json";
      path = communityDashboard {
        id = 25216;
        name = "caddy-standalone-reverse-proxy";
        hash = "sha256-L9B8L1J6Yu0Tdidl1E5huJKZpm7qgxjx1hZKCzaV2bY=";
      };
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
        # 26.05 dropped the default secret_key; this is the old default the DB
        # was encrypted with (rotation needs a 3rd-party tool, see changelog)
        secret_key = "SW2YcwTIb9zpOOhoPsMm";
        cookie_secure = true;
      };

      "auth.anonymous".enabled = false;

      smtp = {
        enabled = true;
        host = "smtp.resend.com:465";
        user = "resend";
        password = "$__file{/run/credentials/grafana.service/smtp-password}";
        from_address = "aliceisjustplaying@gmail.com";
        from_name = "Pix2 Grafana";
      };

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

    provision.alerting.contactPoints.settings = {
      apiVersion = 1;
      contactPoints = [
        {
          orgId = 1;
          name = "email";
          receivers = [
            {
              uid = "pix2-email";
              type = "email";
              settings = {
                addresses = "aliceisjustplaying@gmail.com";
                singleEmail = false;
              };
            }
          ];
        }
      ];
    };

    provision.alerting.policies.settings = {
      apiVersion = 1;
      policies = [
        {
          orgId = 1;
          receiver = "email";
          group_by = [
            "grafana_folder"
            "alertname"
          ];
          group_wait = "30s";
          group_interval = "5m";
          repeat_interval = "4h";
        }
      ];
      resetPolicies = [ 1 ];
    };
  };

  systemd.services.grafana.serviceConfig.LoadCredential = [
    "smtp-password:${config.sops.secrets.plausible-smtp-password.path}"
  ];

  services.caddy.virtualHosts."grafana.pix2.mosphere.at".extraConfig = ''
    encode zstd gzip
    reverse_proxy 127.0.0.1:3000
  '';
}
