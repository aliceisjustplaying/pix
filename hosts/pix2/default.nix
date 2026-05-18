{ lib, ... }:

{
  imports = [
    ../common
  ];

  networking.hostName = "pix2";

  # pix2 is installed and prebuilt before the final migration cutover. Keep the
  # full service definitions in the system closure, but do not auto-start
  # services that would publish routes, join external backends, or mutate shared
  # production state.
  networking.firewall.allowedTCPPorts = lib.mkForce [ 22 ];

  systemd.services = {
    agent-secrets.wantedBy = lib.mkForce [ ];
    agentmemory.wantedBy = lib.mkForce [ ];
    atd.wantedBy = lib.mkForce [ ];
    camofox.wantedBy = lib.mkForce [ ];
    caddy.wantedBy = lib.mkForce [ ];
    clickhouse.wantedBy = lib.mkForce [ ];
    cloudflared.wantedBy = lib.mkForce [ ];
    cron.wantedBy = lib.mkForce [ ];
    github-runner-bluepy-agent-1.wantedBy = lib.mkForce [ ];
    github-runner-bluepy-agent-2.wantedBy = lib.mkForce [ ];
    github-runner-bluepy-agent-3.wantedBy = lib.mkForce [ ];
    hermes-gateway.wantedBy = lib.mkForce [ ];
    hermes-webui.wantedBy = lib.mkForce [ ];
    piclaw.wantedBy = lib.mkForce [ ];
    piclaw-update.wantedBy = lib.mkForce [ ];
    piclaw-update-force.wantedBy = lib.mkForce [ ];
    piclaw-rollback.wantedBy = lib.mkForce [ ];
    piclaw-rollback-force.wantedBy = lib.mkForce [ ];
    piclaw-restart.wantedBy = lib.mkForce [ ];
    plausible.wantedBy = lib.mkForce [ ];
    plausible-postgres.wantedBy = lib.mkForce [ ];
    postgresql.wantedBy = lib.mkForce [ ];
    tailscaled.wantedBy = lib.mkForce [ ];
    tailscaled-autoconnect.wantedBy = lib.mkForce [ ];
  };

  systemd.timers = {
    nix-disk-guard.wantedBy = lib.mkForce [ ];
    nix-gc.wantedBy = lib.mkForce [ ];
    nix-optimise.wantedBy = lib.mkForce [ ];
    restic-backups-r2.wantedBy = lib.mkForce [ ];
  };

  systemd.targets.postgresql.wantedBy = lib.mkForce [ ];

  home-manager.users.agent.systemd.user.services.cli-proxy-api.Install.WantedBy = lib.mkForce [ ];
}
