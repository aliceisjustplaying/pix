# pix.mosphere.at

NixOS host configuration for `pix.mosphere.at`, a Hetzner ARM64 VPS that runs PiClaw, Hermes, agent tooling, and supporting services.

This repo owns the host/platform layer: NixOS modules, Home Manager config for the `agent` user, SOPS-managed secrets, systemd services, local helper commands, and Nix package wrappers used on the box. Application patching/deployment for PiClaw lives in [`piclaw-customizations`](https://github.com/aliceisjustplaying/piclaw-customizations), not here.

## Layout

- `flake.nix` / `flake.lock` — top-level flake, pinned Nix inputs, host overlay, and exported local packages.
- `hosts/pix/default.nix` — host composition, firewall, SSH policy, Tailscale/Cloudflare/PiClaw/Hermes/Plausible imports.
- `disko/pix.nix` — one-disk layout for nixos-anywhere installs.
- `modules/` — NixOS modules for base OS, browser runtime, Tailscale, Cloudflare Tunnel, PiClaw, Hermes, Hermes WebUI, host jobs, bsky boost cron, Plausible, and restic backups.
- `home/agent.nix`, `home/agent/` — Home Manager entry point and focused modules for `agent`: packages, shell aliases, helper commands, model/tool settings, Git/SSH, tmux, and user services.
- `lib/` — shared Nix helpers, including agent service defaults and template rendering.
- `pkgs/` — local package definitions/wrappers for Amp, CLIProxyAPI, Codex ACP, Claude Code ACP, Droid, Gog, Portless, and tsshd.
- `files/` — rendered runtime files: helper scripts, service bootstraps, prompt/config overlays, cron entries, SOPS templates, Caddy config, and tool settings.
- `scripts/` — bootstrap and validation scripts, including dependency freshness checks.
- `secrets/`, `.sops.yaml`, `keys/` — SOPS policy, encrypted runtime secrets, bootstrap key material, and local public keys.
- `INSTALL.md` — first-deploy and day-2 runbook.
- `SECRETS-CHECKLIST.md` — required SOPS secret inventory and generation notes.
- `AGENTS.md` — Pix-specific operating rules for agents working in this repo.

## What Nix manages

Nix owns the host/platform layer:

- NixOS stable `25.11` on `aarch64-linux`, latest kernel, bootloader, swap, journald policy, base packages, and garbage collection.
- The `agent` user, `/workspace` symlink, `/workspace/src`, `/workspace/.pi`, `/workspace/.hermes`, and service state directories.
- SSH access policy: public SSH is disabled after bootstrap; admin access is via Tailscale. Tailnet firewall allows SSH, selected internal web ports, and tsshd UDP `61001-61999`.
- Cloudflare Tunnel for `pix.mosphere.at` → local PiClaw on `127.0.0.1:8080`.
- `piclaw.service`, running from `/workspace/src/piclaw-live` via Bun. The live checkout is managed by `piclaw-customizations`.
- `hermes-gateway.service`, bootstrapping `/workspace/src/hermes-live` into `/workspace/.hermes/venv` and running `hermes gateway run --replace`.
- `hermes-webui.service`, serving `nesquena/hermes-webui` on Tailscale port `8787`.
- `camofox.service`, running the Camofox browser API from `/workspace/src/camofox-browser` when present.
- Plausible Analytics for `https://p.mosphere.at`, fronted by Caddy on public ports 80/443.
- Daily encrypted restic backups of `/workspace` to Cloudflare R2, alongside Hetzner automatic backups.
- Cron/`atd` support for bsky boost jobs.
- Host job systemd units for rebuild/update/rollback/restart/backup operations, with narrow sudo rules for the `agent` user.
- Agent CLI tooling: Bun, Node 24, Go, Python/uv, GitHub CLI, jj, tsshd, `agent-browser`, Amp, Droid, Gog, Claude Code, Codex, CLIProxyAPI, Codex ACP, Claude Code ACP, Portless, media/browser utilities, and local helper scripts.

## What Nix does not manage

- PiClaw application patch stack, upstream sync, prompt overlay, extensions, and deploy validation: owned by `/workspace/src/piclaw-customizations`.
- The running PiClaw live checkout: `/workspace/src/piclaw-live`.
- Clean upstream PiClaw PR work: `/workspace/src/piclaw-fork`.
- Hermes source checkout: `/workspace/src/hermes-live`.
- Hermes mutable state, skills, sessions, pairing data, and venv contents under `/workspace/.hermes`.
- Camofox browser source checkout under `/workspace/src/camofox-browser`.
- OAuth/login/session state for Claude, Codex, Amp, Factory/Droid, and related tools.

## Runtime paths and ports

| Thing | Path / address | Owner |
| --- | --- | --- |
| Canonical workspace | `/workspace` → `/home/agent/workspace` | Nix tmpfiles |
| Pix repo | `/workspace/src/pix` | this repo |
| PiClaw live checkout | `/workspace/src/piclaw-live` | `piclaw-customizations` deploy flow |
| PiClaw rollback target | `/workspace/src/piclaw-live.previous` | `piclaw-customizations` deploy flow |
| Upstream PiClaw fork checkout | `/workspace/src/piclaw-fork` | manual/PR work |
| Hermes checkout | `/workspace/src/hermes-live` | Hermes update flow |
| Hermes home/state | `/workspace/.hermes` | Hermes service/runtime |
| PiClaw state | `/workspace/.piclaw` | PiClaw runtime |
| PiClaw HTTP | `127.0.0.1:8080`, public via `pix.mosphere.at` | `piclaw.service` + Cloudflare Tunnel |
| Hermes WebUI | `0.0.0.0:8787`, Tailscale only | `hermes-webui.service` |
| Plausible | `127.0.0.1:8000`, public via `p.mosphere.at` | Plausible + Caddy |
| Camofox API | port `9377` | `camofox.service` |

## Day-to-day commands on the host

These commands are installed for `agent` under `~/.local/bin` by Home Manager. The mutating commands enqueue fixed systemd units; they do not run ad hoc privileged commands directly.

- `rebuild` / `sync-nix` — pull `/workspace/src/pix` and start `pix-rebuild.service`, which runs `nixos-rebuild switch --flake path:/home/agent/workspace/src/pix#pix`.
- `update` / `update --force` — start `piclaw-update.service` or `piclaw-update-force.service`.
- `rollback` / `rollback --force` — start `piclaw-rollback.service` or `piclaw-rollback-force.service`.
- `piclaw-restart` — start `piclaw-restart.service`.
- `backup` — start `restic-backups-r2.service`.
- `host-result <unit> --wait <seconds>` — wait for a queued host job and print recent journal output.
- `verify-deploy` — run the PiClaw deploy verifier locally without activating a candidate.
- `dependency-freshness` — fail if checked Nix flake/fetcher pins are newer than 24 hours or cannot be verified. Fresh dependency bypasses require an explicit reason and do not bypass verification errors.
- `piclaw-status`, `piclaw-logs` — SSH wrappers for `systemctl status` / `journalctl -u piclaw`.
- `nfu` — update flake inputs and pinned package wrappers, run dependency freshness checks, and build the exported package set.
- `hermes` — wrapper for the live Hermes install under `/workspace/.hermes`.
- `amp-login-proxy`, `amp-login-upstream` — Amp OAuth login helpers for proxied/upstream flows.

Any action that activates a new host or PiClaw runtime (`rebuild`, `update`, `rollback`, `piclaw-restart`, `backup`, direct systemd starts, etc.) should be approved in the current conversation before running.

Shell aliases: `sync-nix` = `rebuild`, `update-force` = `update --force`, `rollback-force` = `rollback --force`.

## Key defaults

- Flake target: `nixosConfigurations.pix` for `aarch64-linux`.
- Nixpkgs: `nixos-25.11`, with selected tools pulled from `nixpkgs-unstable`.
- Public hostname: `pix.mosphere.at`.
- Tailscale hostname/address: `pix.tailec2dc.ts.net` / `100.74.251.100`.
- PiClaw binds locally on `127.0.0.1:8080` and is published by Cloudflare Tunnel.
- Web Push uses `PICLAW_WEB_PUSH_VAPID_SUBJECT=https://pix.mosphere.at` so Apple Home Screen web apps accept outbound VAPID JWTs.
- Notification source markers (`[Local]`, `[Web Push]`) stay hidden by default; set `PICLAW_WEB_NOTIFICATION_DEBUG_LABELS=1` only while debugging delivery routing.
- PiClaw uses the `codex-app-server` backend by default.
- The Piclaw service runs with `ProtectSystem=strict`; host-level changes go through declared host job units.
- Browser/UI validation uses `agent-browser`; Chromium and browser runtime libraries are provided by Nix.
- Persistent host/agent tooling should be added to Nix/Home Manager here, not installed with one-off package-manager commands.
- npm/pnpm/Bun/uv/Cargo dependency installs use release-age gates from managed config; `nfu` also checks Nix flake/fetcher pins before building packages.

## Backups

- **Hetzner automatic backups** — full-disk rolling snapshots, enabled outside Nix via Hetzner.
- **Restic to Cloudflare R2** — daily encrypted `/workspace` backups, excluding caches and rebuildable checkouts, with 7d/4w/3m retention. See `modules/backup.nix`.

Manual backup on the host:

```bash
backup
host-result restic-backups-r2 --wait 900
```

## First deploy and secrets

See [`INSTALL.md`](INSTALL.md) for the A-to-Z install runbook and day-2 operations.
See [`SECRETS-CHECKLIST.md`](SECRETS-CHECKLIST.md) for required SOPS secrets and bootstrap key material.

## Web Push note

For iPhone Safari PWA / Home Screen notifications, PiClaw must advertise a real public VAPID subject. The placeholder fallback used by upstream code, `mailto:notifications@localhost.invalid`, is sufficient for local development but Apple Push rejects it in production with `403 {"reason":"BadJwtToken"}`.

On this host the service env is rendered from [`modules/piclaw.nix`](modules/piclaw.nix), and the correct subject is pinned to `https://pix.mosphere.at`. If iPhone subscriptions appear in `/workspace/.piclaw/web-push/subscriptions.json` but no pushes arrive, verify this env var first.

Optional debug env:

- `PICLAW_WEB_NOTIFICATION_DEBUG_LABELS=1` — show `[Local]` / `[Web Push]` suffixes in notification titles while validating routing. Default is off.
