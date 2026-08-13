{ config, lib, pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  hermesHome = "/workspace/.hermes";
  hermesOverrides = "${hermesHome}/overrides";
  hermesRepo = "/workspace/src/hermes-live";
  hermesVenv = "${hermesHome}/venv";
  hermesSitePackages = "${hermesVenv}/lib/python3.11/site-packages";
  hermesSitecustomize = pkgs.writeText "hermes-sitecustomize.py" (builtins.readFile ../files/hermes/sitecustomize.py);
  tmpl = import ../lib/template.nix;

  servicePath = agentService.runtimePath [ pkgs.uv pkgs.python312 ];
  hermesBuildPath = lib.makeBinPath [
    pkgs.gnumake
    pkgs.npm-hermes
    pkgs.nodejs_24
    pkgs.pkg-config
    pkgs.python312
    pkgs.stdenv.cc
  ];
  hermesLibraryPath = lib.makeLibraryPath [
    pkgs.stdenv.cc.cc.lib
    pkgs.krb5
    pkgs.openssl
    pkgs.icu70
    pkgs.libopus
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
  agentmemoryMemoryProvider = pkgs.writeText "agentmemory-memory-provider.py" (builtins.readFile ../files/hermes/agentmemory-memory-provider.py);
  agentmemoryMcp = "${pkgs.agentmemory}/bin/agentmemory-mcp";
  agentmemoryBootstrap = pkgs.writeShellScript "agentmemory-bootstrap" (builtins.readFile ../files/hermes/agentmemory-bootstrap.sh);
  hermesBootstrap = pkgs.writeShellScript "hermes-bootstrap" (tmpl ../files/hermes/bootstrap.sh {
    inherit hermesBuildPath hermesHome hermesOverrides hermesRepo hermesVenv hermesSitePackages agentmemoryMcp;
    hermesSitecustomize = toString hermesSitecustomize;
    hermesConfig = toString hermesConfig;
    hermesEnvTemplate = toString hermesEnvTemplate;
    hermesLive = toString hermesLive;
    hermesPth = toString hermesPth;
    agentmemoryMemoryProvider = toString agentmemoryMemoryProvider;
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
    "d /home/agent/.agentmemory 0700 agent users - -"
    "d /workspace/src 0755 agent users - -"
    "d /usr/share 0755 root root - -"
    "L+ /usr/share/zoneinfo - - - - ${pkgs.tzdata}/share/zoneinfo"
  ];

  systemd.services."agentmemory" = {
    description = "AgentMemory persistent memory service";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = agentService.serviceDefaults // {
      WorkingDirectory = "/workspace";
      Environment = agentService.env {
        pathPackages = [ pkgs.agentmemory pkgs.iii pkgs.nodejs_24 pkgs.which pkgs.curl pkgs.procps ];
        extra = [
          "AGENTMEMORY_III_VERSION=0.11.2"
          "AGENTMEMORY_URL=http://127.0.0.1:3111"
          "AGENTMEMORY_VIEWER_URL=http://127.0.0.1:3113"
          "AGENTMEMORY_AUTO_COMPRESS=true"
          "AGENTMEMORY_INJECT_CONTEXT=false"
          "EMBEDDING_PROVIDER=local"
          "III_REST_PORT=3111"
          "III_STREAMS_PORT=3112"
          "III_ENGINE_URL=ws://127.0.0.1:49134"
          "OPENAI_API_KEY=CLI_PROXY_API_KEY"
          "OPENAI_BASE_URL=http://127.0.0.1:8317/v1"
          "OPENAI_MODEL=anthropic/claude-haiku-4.5"
        ];
      };
      ExecStartPre = agentmemoryBootstrap;
      ExecStart = "${pkgs.agentmemory}/bin/agentmemory --port 3111";
      ExecStop = "${pkgs.agentmemory}/bin/agentmemory stop --force";
      RestartSec = "10s";
      TimeoutStartSec = "2min";
      TimeoutStopSec = "30s";
    };
  };

  systemd.services."hermes-gateway" = {
    description = "Hermes Agent Gateway";
    after = [ "network-online.target" "agent-secrets.service" "camofox.service" "agentmemory.service" ];
    wants = [ "network-online.target" "agent-secrets.service" "camofox.service" "agentmemory.service" ];
    wantedBy = [ "multi-user.target" ];
    unitConfig.StartLimitIntervalSec = 0;

    serviceConfig = agentService.serviceDefaults // {
      WorkingDirectory = "/workspace";
      EnvironmentFile = config.sops.templates.hermes-service-env.path;
      Environment = agentService.env {
        useRuntimePath = false;
        extra = [
          "HERMES_HOME=${hermesHome}"
          "PYTHONPATH=${hermesOverrides}"
          "VIRTUAL_ENV=${hermesVenv}"
          "PYTHONUNBUFFERED=1"
        ];
      };
      ExecStartPre = hermesBootstrap;
      ExecStart = "${hermesVenv}/bin/hermes gateway run --replace";
      ExecReload = "${pkgs.coreutils}/bin/kill -USR1 $MAINPID";
      RestartSec = "5s";
      RestartMaxDelaySec = "300s";
      RestartSteps = 5;
      RestartForceExitStatus = 75;
      KillMode = "mixed";
      KillSignal = "SIGTERM";
      TimeoutStartSec = "15min";
      TimeoutStopSec = "90s";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };
}
