{ config, lib, pkgs, ... }:
let
  agentHome = "/home/agent";
  hermesHome = "/workspace/.hermes";
  hermesRepo = "/workspace/src/hermes-live";
  hermesVenv = "${hermesHome}/venv";

  servicePath = lib.makeBinPath [
    pkgs.bash
    pkgs.coreutils
    pkgs.curl
    pkgs.diffutils
    pkgs.findutils
    pkgs.ripgrep
    pkgs.fd
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gnumake
    pkgs.tree
    pkgs.unzip
    pkgs.zip
    pkgs.shellcheck
    pkgs.shfmt
    pkgs.gh
    pkgs.ghstack
    pkgs.git
    pkgs.gnupatch
    pkgs.openssh
    pkgs.nodejs_24
    pkgs.python311
    pkgs.jq
    pkgs.procps
    pkgs.sqlite
    pkgs.ffmpeg
    pkgs.yt-dlp
    pkgs.tmux
    pkgs.which
    pkgs.claude-code
    pkgs.codex
  ];

  hermesBootstrap = pkgs.writeShellScript "hermes-bootstrap" ''
    set -euo pipefail

    mkdir -p "${hermesHome}" \
      "${hermesHome}/logs" \
      "${hermesHome}/sessions" \
      "${hermesHome}/skills" \
      "${hermesHome}/pairing" \
      "/workspace/src"

    if [ ! -d "${hermesRepo}/.git" ]; then
      rm -rf "${hermesRepo}"
      git clone --depth=1 https://github.com/NousResearch/hermes-agent.git "${hermesRepo}"
    fi

    if [ ! -f "${hermesHome}/config.yaml" ]; then
      cat > "${hermesHome}/config.yaml" <<'EOF'
model:
  default: claude-opus-4-6
  provider: anthropic
terminal:
  backend: local
  cwd: /workspace
EOF
      chmod 600 "${hermesHome}/config.yaml"
    fi

    if [ ! -f "${hermesHome}/.env" ]; then
      api_server_key="$(${pkgs.coreutils}/bin/head -c 32 /dev/urandom | ${pkgs.coreutils}/bin/od -An -tx1 | ${pkgs.coreutils}/bin/tr -d ' \n')"
      cat > "${hermesHome}/.env" <<EOF
API_SERVER_ENABLED=true
API_SERVER_HOST=127.0.0.1
API_SERVER_PORT=8084
API_SERVER_KEY=$api_server_key
CAMOFOX_URL=http://127.0.0.1:9377
EOF
      chmod 600 "${hermesHome}/.env"
    fi

    rev="$(git -C "${hermesRepo}" rev-parse HEAD)"
    stamp="${hermesHome}/.install-rev"

    if [ ! -x "${hermesVenv}/bin/hermes" ] || [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$rev" ]; then
      rm -rf "${hermesVenv}"
      ${pkgs.uv}/bin/uv venv "${hermesVenv}" --python ${pkgs.python311}/bin/python3.11
      (
        cd "${hermesRepo}"
        export UV_PROJECT_ENVIRONMENT="${hermesVenv}"
        ${pkgs.uv}/bin/uv sync \
          --locked \
          --extra messaging \
          --extra cron \
          --extra cli \
          --extra pty \
          --extra honcho \
          --extra mcp \
          --extra acp
      )
      printf '%s\n' "$rev" > "$stamp"
      chmod 600 "$stamp"
    fi

  '';
in {
  sops.templates.hermes-service-env = {
    restartUnits = [ "hermes.service" ];
    content = ''
      HERMES_HOME=${hermesHome}
      PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${hermesHome} 0700 agent users - -"
    "d ${hermesHome}/logs 0700 agent users - -"
    "d ${hermesHome}/sessions 0700 agent users - -"
    "d ${hermesHome}/skills 0700 agent users - -"
    "d ${hermesHome}/pairing 0700 agent users - -"
    "d /workspace/src 0755 agent users - -"
  ];

  systemd.services.hermes = {
    description = "Hermes Agent Gateway";
    after = [ "network-online.target" "agent-secrets.service" "camofox.service" ];
    wants = [ "network-online.target" "agent-secrets.service" "camofox.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "agent";
      Group = "users";
      WorkingDirectory = "/workspace";
      EnvironmentFile = config.sops.templates.hermes-service-env.path;
      Environment = [
        "HOME=${agentHome}"
        "USER=agent"
        "XDG_CONFIG_HOME=${agentHome}/.config"
        "PYTHONUNBUFFERED=1"
      ];
      ExecStartPre = hermesBootstrap;
      ExecStart = "${hermesVenv}/bin/hermes gateway run --replace";
      Restart = "always";
      RestartSec = "10s";
      TimeoutStartSec = "15min";
      UMask = "0077";
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = false;
      ReadWritePaths = [ "${agentHome}" "/workspace" ];
    };
  };
}
