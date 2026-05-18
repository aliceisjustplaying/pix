{ config, ... }:
{
  sops.secrets.plausible-secret-key-base = { };
  sops.secrets.plausible-smtp-password = { };

  services.plausible = {
    enable = true;

    server = {
      baseUrl = "https://p.mosphere.at";
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

  services.clickhouse.extraServerConfig = ''
    <clickhouse>
      <trace_log remove="remove" />
      <metric_log remove="remove" />
      <asynchronous_metric_log remove="remove" />
      <query_metric_log remove="remove" />
      <processors_profile_log remove="remove" />
    </clickhouse>
  '';

  services.caddy = {
    enable = true;
    email = "aliceisjustplaying@gmail.com";

    virtualHosts."p.mosphere.at".extraConfig = builtins.readFile ../files/caddy/plausible.caddy;
    virtualHosts."pix.mosphere.at".extraConfig = builtins.readFile ../files/caddy/piclaw.caddy;
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  systemd.services.plausible.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "10s";
  };
}
