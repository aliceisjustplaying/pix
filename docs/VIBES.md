# Vibes on `pix`

This host runs Vibes alongside PiClaw:

- PiClaw: `127.0.0.1:8080` -> `https://pix.mosphere.at`
- Vibes: `100.74.251.100:8081`, reachable only through Tailscale

The Vibes instance is single-user, backed by Codex through ACP, and intentionally not published on the public internet.

## What Nix manages

Repo-managed pieces:

- `modules/vibes.nix` defines `systemd.services.vibes`
- `pkgs/vibes.nix` packages upstream `rcarmo/vibes` from the Go upstream
- `pkgs/codex-acp.nix` packages `zed-industries/codex-acp`
- `home/agent.nix` installs `vibes` and `codex-acp` into the `agent` profile
- `hosts/pix/default.nix` imports the Vibes module and opens `8081` on `tailscale0`

Service defaults:

- `VIBES_HOST=100.74.251.100`
- `VIBES_PORT=8081`
- `VIBES_DB_PATH=/workspace/.pi/vibes/vibes.db`
- `VIBES_AGENT_NAME=Codex`
- `VIBES_DEFAULT_AGENT=acp`
- `VIBES_PI_ENABLED=false`
- `VIBES_ACP_AGENT=${codex-acp}/bin/codex-acp`
- working directory `/workspace`

Runtime state lives under `/workspace/.pi/vibes`.

## Access model

Vibes is tailscale-only:

- Vibes listens on `8081`
- the firewall only permits that port on `tailscale0`
- there is no intended public hostname

Use one of:

- `http://100.74.251.100:8081`
- `http://pix:8081` if MagicDNS is enabled in the tailnet

## Deploy and verify

Rebuild the host in the normal way:

```bash
host-queue vibes-update 'sudo nixos-rebuild switch --flake path:/home/agent/workspace/src/pix#pix'
host-result vibes-update-<epoch> --wait 900
```

Useful checks:

```bash
curl -s http://127.0.0.1:8081/health
curl -s http://100.74.251.100:8081/health
curl -s http://100.74.251.100:8081/agent/models
systemctl status vibes.service
```
