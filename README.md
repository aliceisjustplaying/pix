# pix

NixOS host configuration for the Pix machines. The active production host is
`pix.mosphere.at`; the repo also carries `pix2` for the x86_64 Hetzner
migration.

This repo owns the host/platform layer: NixOS modules, Home Manager config for
the `agent` user, SOPS-managed secrets, systemd services, local helper
commands, package wrappers, and first-deploy scripts. Application source trees
and mutable runtime state live under `/workspace` and are only wired here.

## Flake Targets

| Target | System | Host module | Notes |
| --- | --- | --- | --- |
| `.#nixosConfigurations.pix` | `aarch64-linux` | `hosts/pix/default.nix` | Current ARM production host, hostname `pix` |
| `.#nixosConfigurations.pix2` | `x86_64-linux` | `hosts/pix2/default.nix` | Hetzner x86_64 migration target, hostname `pix2` |

Package exports are built for both `aarch64-linux` and `x86_64-linux`:
`amp-code`, `claude-code-acp`, `cli-proxy-api`, `codex-acp`, `droid`,
`gogcli`, `portless`, `tirith`, and `vet-run`.

## Layout

- `flake.nix` / `flake.lock` - inputs, overlays, host package set, package exports, and NixOS targets.
- `hosts/common/default.nix` - shared host composition, SSH policy, firewall, SOPS defaults, Home Manager wiring, and common imports.
- `hosts/pix/`, `hosts/pix2/` - host-specific host identities.
- `disko/pix.nix` - one-disk layout used by nixos-anywhere.
- `modules/` - NixOS modules for base OS, browser runtime, Tailscale, Cloudflare Tunnel, PiClaw, Hermes, Hermes WebUI, Plausible, backups, host jobs, bsky cron, and Bluepy GitHub runners.
- `home/agent/` - Home Manager modules for packages, shell aliases, dotfiles, model/tool config, Git, SSH, tmux, and the user-level CLIProxyAPI service.
- `files/` - rendered scripts, service bootstraps, CLI config templates, SOPS templates, Caddy config, and package-manager settings.
- `pkgs/` - local package definitions/wrappers for Amp, Claude Code ACP, CLIProxyAPI, Codex ACP, Droid, Gog, Portless, and wrapped `tsshd`.
- `scripts/` - deployment, bootstrap-key, and dependency validation helpers.
- `docs/pix2-migration.md` - x86_64 migration checklist.
- `INSTALL.md`, `SECRETS-CHECKLIST.md`, `AGENTS.md` - install, secret, and agent runbooks.

## Managed Host Surface

Shared config imports the same service stack for both host targets:

- Base OS on NixOS `25.11`, with `nix-command`/flakes, daily GC, automatic store optimisation, disk-pressure GC guard, zram, 8 GiB swapfile, latest kernel from `kernel-nixpkgs`, journald/coredump limits, and common CLI tooling.
- `agent` user with passwordless wheel sudo, SSH keys, `/workspace -> /home/agent/workspace`, `/workspace/src`, `/workspace/.hermes`, and other service state directories.
- Tailscale with `tag:pix`, DNS acceptance disabled, and a 30s autoconnect timeout.
- OpenSSH locked to `agent`, no passwords, no root login, no X11 forwarding, firewall closed except declared ports.
- Cloudflare Tunnel from the configured token.
- PiClaw service from `/workspace/src/piclaw-live`, with env rendered from SOPS.
- Hermes gateway from `/workspace/src/hermes-live`, bootstrapped into `/workspace/.hermes/venv`, with Hindsight as the local memory provider.
- Hermes WebUI from `/workspace/src/hermes-webui`, using `/workspace/.hermes/webui`.
- Plausible on `https://p.mosphere.at`, backed by PostgreSQL, ClickHouse, and Caddy.
- Restic backups of `/workspace` to Cloudflare R2, daily with 7d/4w/3m retention.
- Camofox browser API from `/workspace/src/camofox-browser` when that checkout exists.
- Bluepy GitHub runners `bluepy-agent-1..3` when `/home/agent/.config/github-runner/bluepy-token` exists.
- bsky boost cron jobs and `atd`.

## Ports

| Port | Scope | Owner |
| --- | --- | --- |
| `22/tcp` | Tailscale only | SSH |
| `80/tcp`, `443/tcp` | Public and Tailscale | Caddy/Plausible plus host web entrypoints |
| `8787/tcp` | Tailscale only | Hermes WebUI |
| `61001-61999/udp` | Tailscale only | Wrapped `tsshd` |
| `127.0.0.1:8080` | Local | PiClaw |
| `127.0.0.1:8084` | Local | Hermes API server |
| `127.0.0.1:8317` | Local user service | CLIProxyAPI |
| `127.0.0.1:9177` | Local | Hindsight API for Hermes memory |
| `127.0.0.1:5433` | Local | Hindsight embedded PostgreSQL when memory is active |
| `127.0.0.1:8000` | Local | Plausible |
| `9377/tcp` | Service process | Camofox API |

## Runtime Paths

| Path | Owner |
| --- | --- |
| `/workspace/src/pix` | this repo |
| `/workspace/src/piclaw-customizations` | PiClaw patch/deploy flow |
| `/workspace/src/piclaw-live` | running PiClaw checkout |
| `/workspace/src/piclaw-live.previous` | PiClaw rollback target |
| `/workspace/src/piclaw-fork` | upstream PiClaw PR work |
| `/workspace/src/hermes-live` | Hermes source checkout |
| `/workspace/src/hermes-webui` | Hermes WebUI checkout |
| `/workspace/src/camofox-browser` | optional Camofox checkout |
| `/workspace/.piclaw` | PiClaw mutable state |
| `/workspace/.hermes` | Hermes home, venv, logs, sessions, skills, pairing, WebUI state |
| `/home/agent/.hindsight`, `/home/agent/.pg0` | Hindsight profile and embedded PostgreSQL state |
| `/workspace/github-runners/bluepy-agent-*` | Bluepy runner work directories |
| `/workspace/agent-worktrees/bluepy` | Bluepy runner agent worktrees |

## Agent User Tooling

Home Manager installs Bun, Node 24, Go 1.26, Python, uv, GitHub CLI, Google
Cloud CLI, jj, tmux, zellij, todoist (sachaos/todoist CLI), `agent-browser`,
`tirith`, `vet`, Firefox, Playwright, media tools, the Opus codec, `tsshd`, and
the local packages exported by this flake. It also renders:

- package-manager freshness gates: npm `min-release-age`, Bun/pnpm `minimumReleaseAge`, uv `exclude-newer`, and Cargo through the Menhera 1d proxy.
- Amp, Factory/Droid, and CLIProxyAPI model config from `home/agent/model-catalog.nix`.
- Claude and Codex agent instruction files.
- Git and SSH defaults for GitHub, Tangled, and localhost host-job access.
- shell aliases for host jobs, Pix/PiClaw navigation, Hermes, Claude, Codex, tmux, and zellij.

The user-level `cli-proxy-api.service` runs
`cli-proxy-api --config ~/.cli-proxy-api/config.yaml` and serves OAuth-backed
model proxy traffic on `127.0.0.1:8317`.

## Host Commands

Home Manager installs these wrappers under `~/.local/bin`. Mutating wrappers
queue NixOS-declared systemd units with narrow sudo rules, then return
immediately. Use `host-result` to wait and inspect logs.

| Command | Unit / behavior |
| --- | --- |
| `rebuild`, `sync-nix` | queue `pix-rebuild.service`; pulls `/workspace/src/pix`, then `nixos-rebuild switch --flake path:/home/agent/workspace/src/pix#<hostname>` |
| `update`, `update-force` | queue `piclaw-update.service` / `piclaw-update-force.service` |
| `rollback`, `rollback-force` | queue `piclaw-rollback.service` / `piclaw-rollback-force.service` |
| `piclaw-restart` | queue `piclaw-restart.service` |
| `backup` | queue `restic-backups-r2.service` |
| `host-result <unit> --wait <seconds>` | wait for a host-job unit and print recent journal |
| `verify-deploy` | run PiClaw deploy verification from `/workspace/src/piclaw-customizations` |
| `dependency-freshness` | run `scripts/check-dependency-freshness.py` |
| `nfu` | update flake inputs and local package pins, run freshness checks, and build exported packages |
| `nfur` | shell alias for `nfu && rebuild` |
| `piclaw-status`, `piclaw-logs` | SSH wrappers around service status/logs |
| `hermes`, `h`, `ht` | run Hermes from `/workspace/.hermes` |
| `amp-login-proxy`, `amp-login-upstream` | Amp login helpers for proxy/upstream modes |

Host activation commands should be approved in the current conversation before
running.

## Updates And Freshness

`nfu` is the tracked updater for this repo. It handles flake inputs plus local
package pins for Amp, Claude Code ACP, CLIProxyAPI, Codex ACP, Droid, Gog, and
Portless, then validates the exported package set with `nix build`.

The default freshness floor is 24 hours. Nix flake/fetcher pins are checked by
`scripts/check-dependency-freshness.py`; npm/Bun/pnpm/uv/Cargo have managed
resolver gates. Temporary bypasses require both `PIX_ALLOW_FRESH_DEPS=1` and a
`PIX_FRESH_DEPS_REASON`.

## Boundaries

Nix manages platform wiring, not app source or mutable user/session state:

- PiClaw patch stack and deploy logic live in `/workspace/src/piclaw-customizations`.
- PiClaw, Hermes, Hermes WebUI, and Camofox checkouts are mutable runtime/source checkouts under `/workspace/src`.
- Hermes sessions, pairing data, skills, venv, logs, and Hindsight memory state are mutable runtime data.
- OAuth/login/session state for Claude, Codex, Amp, Factory/Droid, Gog, and related tools is not declared here.
- GitHub runner registration tokens are expected at `/home/agent/.config/github-runner/bluepy-token`.

## Deploy And Migration

First install uses `scripts/deploy.sh` with nixos-anywhere:

```bash
scripts/deploy.sh <server-ip>
scripts/deploy.sh --host pix2 <server-ip>
```

`scripts/prepare-bootstrap-key.sh` creates the SOPS host age key material for
nixos-anywhere extra files. See `INSTALL.md` for first deploy and
`docs/pix2-migration.md` for the x86_64 migration runbook. The `pix2` host
configuration intentionally boots in staging mode until cutover: SSH stays
available, while production services and tunnels are not auto-started.

## Web Push

PiClaw’s service env is rendered from `files/sops/piclaw.env`. The VAPID
subject is pinned to `https://pix.mosphere.at` because Apple Home Screen web
apps reject placeholder `mailto:` subjects. Notification source labels are off
by default; set `PICLAW_WEB_NOTIFICATION_DEBUG_LABELS=1` only while debugging
delivery routing.
