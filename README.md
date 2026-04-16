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
- Web Push uses `PICLAW_WEB_PUSH_VAPID_SUBJECT=https://pix.mosphere.at` so Apple Home Screen web apps accept outbound VAPID JWTs
- Notification source markers (`[Local]`, `[Web Push]`) stay hidden by default; set `PICLAW_WEB_NOTIFICATION_DEBUG_LABELS=1` only while debugging delivery routing
- Tailscale for admin access only
- System packages include `chromium` for Playwright/browser validation and `zig` for rebuilding vendored `ghostty-web` wasm artifacts when needed

## What Nix manages vs. what it doesn't

**Nix owns the platform:** kernel, users, secrets, firewall, systemd services, env vars, directory structure.

**PiClaw is an application managed by the agent** via `piclaw-customizations`. That repo owns the update script, patches, extensions, and system prompt generation.

## Backups

- **Hetzner automatic backups** — full-disk rolling snapshots
- **Restic to Cloudflare R2** — daily encrypted `/workspace` backups (excluding caches and rebuildable checkouts), 7d/4w/3m retention. See `modules/backup.nix`.

## Day-to-day

See [`INSTALL.md`](INSTALL.md) for first-deploy runbook and day-2 operations.
See [`SECRETS-CHECKLIST.md`](SECRETS-CHECKLIST.md) for secrets prep.

## Web Push note

For iPhone Safari PWA / Home Screen notifications, PiClaw must advertise a real public VAPID subject. The placeholder fallback used by upstream code, `mailto:notifications@localhost.invalid`, is sufficient for local development but Apple Push rejects it in production with `403 {"reason":"BadJwtToken"}`.

On this host the service env is rendered from [`modules/piclaw.nix`](modules/piclaw.nix), and the correct subject is pinned to `https://pix.mosphere.at`. If iPhone subscriptions appear in `/workspace/.piclaw/web-push/subscriptions.json` but no pushes arrive, verify this env var first.

Optional debug env:

- `PICLAW_WEB_NOTIFICATION_DEBUG_LABELS=1` — show `[Local]` / `[Web Push]` suffixes in notification titles while validating routing. Default is off.
