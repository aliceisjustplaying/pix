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

  services.caddy = {
    enable = true;
    email = "aliceisjustplaying@gmail.com";

    virtualHosts."p.mosphere.at".extraConfig = ''
      encode zstd gzip
      reverse_proxy 127.0.0.1:8000
    '';
  };

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  systemd.services.plausible.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "10s";
  };
}
