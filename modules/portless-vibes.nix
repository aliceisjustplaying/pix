{ pkgs, ... }:
let
  agentService = import ../lib/agent-service.nix { inherit pkgs; };
  agentHome = agentService.home;
  servicePath = agentService.path [
    pkgs.nodejs_24
    pkgs.tailscale
  ];
  portlessCli = "${pkgs.portless}/libexec/portless/dist/cli.js";
in {
  systemd.tmpfiles.rules = [
    "d /workspace/.pi/portless 0700 agent users - -"
  ];

  systemd.services = {
    vibes-claude = {
      wantedBy = pkgs.lib.mkForce [];
      enable = false;
    };

    portless-vibes = {
      description = "Portless Tailscale exposure for Vibes";
      after = [ "network-online.target" "tailscaled.service" "vibes.service" ];
      wants = [ "network-online.target" "tailscaled.service" "vibes.service" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = agentService.serviceDefaults // {
        WorkingDirectory = "/workspace";
        Environment = [
          "HOME=${agentHome}"
          "USER=agent"
          "XDG_CONFIG_HOME=${agentHome}/.config"
          "PORTLESS_STATE_DIR=/workspace/.pi/portless"
          "PORTLESS_LAN=0"
          "PORTLESS_TAILSCALE=1"
          "PORTLESS_HTTPS=0"
          "PORTLESS_PORT=18080"
          "PORTLESS_SYNC_HOSTS=0"
          "PATH=${agentHome}/.local/bin:${agentHome}/.bun/bin:${servicePath}"
        ];
        ExecStart = "${pkgs.nodejs_24}/bin/node ${portlessCli} --name vibes --tailscale --force --app-port 8081 -- ${pkgs.coreutils}/bin/sleep infinity";
      };
    };
  };
}
