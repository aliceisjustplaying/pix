{ config, lib, pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  hermesHome = "/workspace/.hermes";
  hermesOverrides = "${hermesHome}/overrides";
  hermesRepo = "/workspace/src/hermes-live";
  hermesVenv = "${hermesHome}/venv";
  hermesSitePackages = "${hermesVenv}/lib/python3.12/site-packages";
  hermesSitecustomize = pkgs.writeText "hermes-sitecustomize.py" (builtins.readFile ../files/hermes/sitecustomize.py);
  tmpl = import ../lib/template.nix;

  servicePath = agentService.runtimePath [ pkgs.uv pkgs.python312 ];
  hermesLibraryPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.krb5
    pkgs.openssl
    pkgs.icu70
    pkgs.lz4
    pkgs.readline
    pkgs.xz
    pkgs.zlib
    pkgs.zstd
  ];
  hermesTimezonePath = "${pkgs.tzdata}/share/zoneinfo";

  hermesLive = pkgs.writeText "hermes-live" (tmpl ../files/hermes/hermes-live.sh {
    inherit hermesHome hermesOverrides hermesVenv;
  });
  hermesConfig = pkgs.writeText "hermes-config.yaml" (builtins.readFile ../files/hermes/config.yaml);
  hermesEnvTemplate = pkgs.writeText "hermes-env.template" (builtins.readFile ../files/hermes/env.template);
  hermesPth = pkgs.writeText "hermes-home-overrides.pth" (tmpl ../files/hermes/hermes-home-overrides.pth {
    inherit hermesOverrides;
  });
  hermesBootstrap = pkgs.writeShellScript "hermes-bootstrap" (tmpl ../files/hermes/bootstrap.sh {
    inherit hermesHome hermesOverrides hermesRepo hermesVenv hermesSitePackages;
    hermesSitecustomize = toString hermesSitecustomize;
    hermesConfig = toString hermesConfig;
    hermesEnvTemplate = toString hermesEnvTemplate;
    hermesLive = toString hermesLive;
    hermesPth = toString hermesPth;
    coreutilsBin = "${pkgs.coreutils}/bin";
    gnusedBin = "${pkgs.gnused}/bin";
    python = "${pkgs.python312}/bin/python3.12";
    uv = "${pkgs.uv}/bin/uv";
  });
in {
  sops.secrets.gog-keyring-password = {
    restartUnits = [ "hermes-gateway.service" ];
  };

  sops.templates.hermes-service-env = {
    restartUnits = [ "hermes-gateway.service" ];
    content = tmpl ../files/sops/hermes-service.env {
      inherit hermesHome hermesOverrides agentHome servicePath hermesLibraryPath hermesTimezonePath;
      gogKeyringPassword = config.sops.placeholder.gog-keyring-password;
    };
  };

  systemd.tmpfiles.rules = [
    "d ${hermesHome} 0700 agent users - -"
    "d ${hermesOverrides} 0700 agent users - -"
    "d ${hermesHome}/logs 0700 agent users - -"
    "d ${hermesHome}/sessions 0700 agent users - -"
    "d ${hermesHome}/skills 0700 agent users - -"
    "d ${hermesHome}/pairing 0700 agent users - -"
    "d /workspace/src 0755 agent users - -"
    "d /usr/share 0755 root root - -"
    "L+ /usr/share/zoneinfo - - - - ${pkgs.tzdata}/share/zoneinfo"
  ];

  systemd.services."hermes-gateway" = {
    description = "Hermes Agent Gateway";
    after = [ "network-online.target" "agent-secrets.service" "camofox.service" ];
    wants = [ "network-online.target" "agent-secrets.service" "camofox.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = agentService.serviceDefaults // {
      WorkingDirectory = "/workspace";
      EnvironmentFile = config.sops.templates.hermes-service-env.path;
      Environment = agentService.env {
        useRuntimePath = false;
        extra = [
          "PYTHONUNBUFFERED=1"
        ];
      };
      ExecStartPre = hermesBootstrap;
      ExecStart = "${hermesVenv}/bin/hermes gateway run --replace";
      RestartSec = "10s";
      TimeoutStartSec = "15min";
    };
  };
}
