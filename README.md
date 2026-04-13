# pix.mosphere.at

NixOS host for PiClaw on a Hetzner ARM64 VPS.

## Layout

- `flake.nix` — top-level flake
- `hosts/pix/default.nix` — host-specific config
- `disko/pix.nix` — disk layout
- `modules/` — service modules (base, tailscale, cloudflared, piclaw, backup)
- `home/agent.nix` — Home Manager config for `agent`
- `scripts/` — `deploy.sh` (nixos-anywhere), `prepare-bootstrap-key.sh`
- `secrets/` — SOPS policy and encrypted secrets file

## Key defaults

- NixOS stable `25.11`, latest kernel
- PiClaw runs from `/workspace/src/piclaw-live`, managed by [`piclaw-customizations`](https://github.com/aliceisjustplaying/piclaw-customizations)
- Upstream PR work from `/workspace/src/piclaw-fork`
- Binds `127.0.0.1:8080`, published via Cloudflare Tunnel as `pix.mosphere.at`
- Tailscale for admin access only

## What Nix manages vs. what it doesn't

**Nix owns the platform:** kernel, users, secrets, firewall, systemd services, env vars, directory structure.

**PiClaw is an application managed by the agent** via `piclaw-customizations`. That repo owns the update script, patches, extensions, and system prompt generation.

## Backups

- **Hetzner automatic backups** — full-disk rolling snapshots
- **Restic to Cloudflare R2** — daily encrypted `/workspace` backups (excluding caches and rebuildable checkouts), 7d/4w/3m retention. See `modules/backup.nix`.

## Day-to-day

See [`INSTALL.md`](INSTALL.md) for first-deploy runbook and day-2 operations.
See [`SECRETS-CHECKLIST.md`](SECRETS-CHECKLIST.md) for secrets prep.
