# Workspace

You're on the Hermes NixOS host managed by the `pix` flake. Hermes is the only application stack: gateway, WebUI, AgentMemory, Camofox, and its local model proxy. **Treat Hermes and its supporting services as off-limits unless the user explicitly says they're working on them.**

Canonical tracked copy: `/workspace/src/pix/AGENTS.md`. Keep `/workspace/AGENTS.md` byte-for-byte aligned.

## Don't (without explicit per-turn approval)

- Touch hermes, hermes-webui, or their service files / configs.
- Run host-job commands: `rebuild` or `backup`. Same for any direct `sudo nixos-rebuild` or service restart.
- Delete `/workspace/.piclaw/store/messages.db`. Ever.
- Stack untested patches in any deploy patch tree — each patch must pass `git apply --check`, a clean build, and a smoke test before the next one. When a patch makes things worse, bisect, don't layer. `.rej` / `.orig` files are debris.
- Install host tooling ad hoc (`nix profile install`, `brew`, `apt`). Persistent tools go through `/workspace/src/pix` and the `rebuild` path.
- Open PRs.

## Host commands (`~/.local/bin`)

All async — they call `sudo systemctl start --no-block <unit>` and return immediately. Poll with `host-result`.

- `rebuild` → `pix-rebuild.service` → `nixos-rebuild switch --flake path:/home/agent/workspace/src/pix#pix2`.
- `backup` → `restic-backups-r2.service`.
- `host-result <unit> [--wait <s>]` — read recent journal of a queued unit. Use after any async job, especially ones that may kill the calling agent.
- `dependency-freshness`, `nfu` — flake/pin checks and updates.

Alias: `sync-nix`=`rebuild`.

## Paths

- `/workspace` → symlink to `/home/agent/workspace`. For Nix `path:` inputs, prefer the real `/home/agent/workspace/...` path.
- `/workspace/src/pix` — NixOS host config, home-manager, secrets, service defs. Authoritative.
- `/workspace/src/hermes-live`, `/workspace/src/hermes-webui`, `/workspace/.hermes/` — Hermes runtime. Off-limits unless asked.
- `/workspace/notes/reference/nixos-gotchas.md` — known NixOS pitfalls (setuid wrappers, Playwright, Bun global state).

## Browser tooling

Two tools, two jobs:

- **Ad-hoc UI verification** (clicking around, taking a screenshot, checking a CSS regression, manual exploratory) → `agent-browser`. Start with `agent-browser skills get core --full` for the command surface.
- **Smoke tests / repeatable checks** → Playwright. **Browsers ARE installed on this host — via Nix.** If Playwright says browsers are missing or fails to launch Chromium, the bundled binary is failing to resolve shared libs; **do not `npx playwright install`**. Use the Nix-provided bundle: `nix build nixpkgs#playwright-driver.browsers -o /tmp/playwright-browsers` and point Playwright at it (project-specific env var, e.g. `PICLAW_PLAYWRIGHT_EXECUTABLE_PATH` for piclaw). Full incantation in `/workspace/notes/reference/nixos-gotchas.md`.

Don't reach for screenshots-by-hand when `agent-browser` will do; don't write a one-off Playwright test for a single manual check.

## Signing

When signing PRs or PR comments, use `[Agent] in [Harness] (<MODEL_NAME>)` — e.g. `Codex in Hermes (gpt-5.5)`, `Claude in Claude Code (claude-opus-4-7)`. Models self-identify unreliably; if a CLI flag, env var, or settings entry exposes the model authoritatively, query it before signing.
