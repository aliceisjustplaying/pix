{ config, lib, ... }:
let
  cfg = config.pix.plausible;
in
{
  options.pix.plausible = {
    enable = lib.mkEnableOption "Plausible Analytics" // {
      default = true;
    };

    domain = lib.mkOption {
      type = lib.types.str;
      default = "p.mosphere.at";
      description = "Public hostname for Plausible.";
    };

    servePixProxy = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether this host also serves the pix.mosphere.at Piclaw proxy.";
    };
  };

  config = {
    sops.secrets.plausible-secret-key-base = { };
    sops.secrets.plausible-smtp-password = { };

    services.plausible = {
      enable = cfg.enable;

      server = {
        baseUrl = "https://${cfg.domain}";
        secretKeybaseFile = config.sops.secrets.plausible-secret-key-base.path;
        disableRegistration = true;
        listenAddress = "127.0.0.1";
        port = 8000;
      };

      mail = {
        email = "aliceisjustplaying@gmail.com";
        smtp = {
          hostAddr = "smtp.resend.com";
          hostPort = 465;
          user = "resend";
          passwordFile = config.sops.secrets.plausible-smtp-password.path;
          enableSSL = true;
        };
      };
    };

    # Monitoring on pix2 still scrapes ClickHouse after Plausible moves away.
    services.clickhouse.enable = true;
    services.clickhouse.extraServerConfig = ''
      <clickhouse>
        <trace_log remove="remove" />
        <metric_log remove="remove" />
        <asynchronous_metric_log remove="remove" />
        <query_metric_log remove="remove" />
        <processors_profile_log remove="remove" />
        <prometheus>
          <endpoint>/metrics</endpoint>
          <port>9363</port>
          <metrics>true</metrics>
          <events>true</events>
          <asynchronous_metrics>true</asynchronous_metrics>
        </prometheus>
      </clickhouse>
    '';

    services.caddy = {
      enable = true;
      email = "aliceisjustplaying@gmail.com";
      globalConfig = ''
        acme_ca https://acme.zerossl.com/v2/DV90
      '';

      virtualHosts = lib.optionalAttrs cfg.enable {
        ${cfg.domain}.extraConfig = builtins.readFile ../files/caddy/plausible.caddy;
      }
      // lib.optionalAttrs cfg.servePixProxy {
        "pix.mosphere.at".extraConfig = builtins.readFile ../files/caddy/piclaw.caddy;
      };
    };

    networking.firewall.allowedTCPPorts = [
      80
      443
    ];

    systemd.services.plausible.serviceConfig = lib.mkIf cfg.enable {
      Restart = "on-failure";
      RestartSec = "10s";
    };
  };
}
