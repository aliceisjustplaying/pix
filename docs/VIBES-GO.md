# Vibes Go on `pix`

This host now runs the Go port of Vibes as a second tailscale-only UI:

- PiClaw: `127.0.0.1:8080` -> `https://pix.mosphere.at`
- Vibes: `0.0.0.0:8081`, reachable only through Tailscale
- Vibes Go: `0.0.0.0:8082`, reachable only through Tailscale

The Go instance is not published on the public internet.

## What Nix manages

Repo-managed pieces:

- `modules/vibes-go.nix` defines `systemd.services.vibes-go`
- `pkgs/vibes-go.nix` packages upstream `rcarmo/vibes` from branch `go`
- `pkgs/codex-acp.nix` provides the ACP bridge
- `hosts/pix/default.nix` imports the module and opens `8082` on `tailscale0`

Service defaults:

- `VIBES_HOST=0.0.0.0`
- `VIBES_PORT=8082`
- `VIBES_DB_PATH=/workspace/.pi/vibes-go/vibes.db`
- `VIBES_AGENT_NAME=Codex`
- `VIBES_DEFAULT_AGENT=acp`
- `VIBES_PI_ENABLED=false`
- `VIBES_ACP_AGENT=${codex-acp}/bin/codex-acp`
- working directory `/workspace`

Runtime state lives under `/workspace/.pi/vibes-go`.

## Current upstream gap

The `go` branch head currently serves the frontend shell and `/health`, but does not mount the core API route groups yet.

To keep the Go UI usable on this host, the packaged build carries a small local patch that reverse-proxies any unhandled route to the existing Codex-backed `vibes` service on `127.0.0.1:8081`.

That means:

- the UI on `8082` is the Go port
- agent, workspace, timeline, SSE, and model APIs are still provided by the existing Python service on `8081`
- `vibes-go.service` depends on `vibes.service`

## Access model

`vibes-go.mosphere.at` is reserved in Cloudflare for future use, but it should not forward to `8082` yet.

Current intended access is still tailscale-only:

- `http://100.74.251.100:8082`
- `http://pix:8082` if MagicDNS is enabled in the tailnet

## Packaging notes

The Go port currently needs Go `1.26.2`, so `pkgs/vibes-go.nix` uses `buildGo126Module`.

The package is not installed into the `agent` shell profile because the upstream Go binary is also named `vibes`, which would collide with the existing Python package in `home.packages`.

## Deploy and verify

Rebuild the host in the normal way:

```bash
host-queue vibes-go-update 'sudo nixos-rebuild switch --flake path:/home/agent/workspace/src/pix#pix'
host-follow vibes-go-update-<epoch>
```

Useful checks:

```bash
curl -s http://127.0.0.1:8082/health
curl -s http://100.74.251.100:8082/health
curl -s http://100.74.251.100:8082/agent/models
systemctl status vibes-go.service
```
