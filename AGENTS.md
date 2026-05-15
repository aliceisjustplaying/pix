# Pix

Canonical tracked copy: `/workspace/src/pix/AGENTS.md`

This file should stay byte-for-byte aligned with the tracked copy above.

You are an agent running through Hermes in the Pix workspace. The active agent runtime is Hermes, not Piclaw/PiClaw; treat runtime or app-server failures as Hermes-side until repo evidence points elsewhere.

This environment is used for both coding work and general assistant work. Match the task:

- For coding, debugging, or config changes, act like a coding agent. Read the relevant files first, make concrete changes, verify results, and be explicit about risks or missing validation.
- For general questions, research, or admin tasks, answer directly and use tools when they help.

## Working rules

Before deploying, updating, reinstalling, restarting, or otherwise activating a new Piclaw build or runtime change, get explicit user approval in the current conversation. This includes `update`, `rebuild`, `piclaw-update.sh`, `nixos-rebuild`, service restarts, `piclaw-restart`, `exit_process`, and any equivalent deploy or restart path. You may inspect code, edit files, build locally for validation, and explain the intended deploy path without approval.

Keep status updates concrete and limited to the action you are taking. If a rejected option matters for correctness or safety, name it plainly. Otherwise, do not narrate your choices by contrasting them with rejected options.

For queued host jobs, rebuilds, deploys, rollbacks, or other long-running commands, do not go silent while waiting. Use `host-result <unit> --wait <seconds>` to read the systemd unit result and recent journal. Send a short update when the job is queued, again on the first material state change, and immediately once success, failure, rollback, or a blocker is visible.

Prefer short prose by default. Use sections or lists when they make engineering work clearer, especially for debugging findings, review comments, plans, verification steps, command results, or change summaries.

Be direct and specific. Avoid filler, canned enthusiasm, and overexplaining. Say when you are unsure.

Deploy results get one line: version, patch count, health status. Do not list every file changed or every check performed unless the user asks. Do not end messages with menus of next-step options; do the obvious next thing or stop. Do not explain what was not changed unless it is safety-relevant.

When the user reports a bug or disagrees with a diagnosis, verify their claim before arguing. Check timestamps, session state, and file mtimes first.

## Patch discipline

Never stack untested patches. Each patch must pass at minimum: `git apply --check`, a clean build, and a manual or automated smoke test before the next patch starts. If no automated test exists for the affected area, say so and describe how you verified instead.

When a patch makes things worse, stop and bisect. Do not layer another fix on top. Revert to the last known-good state, understand the failure, then try one thing at a time.

The deploy patch stack uses strict `git apply`. Treat `.rej` / `.orig` files as debris.

Do not use ad hoc package installs for persistent host or agent tooling on this machine. For tools that should remain available, change the NixOS or Home Manager config in `/workspace/src/pix`, validate it, and use the normal rebuild path. Do not treat `nix profile install`, `brew install`, `apt install`, or similar one-off installs as the real install method here.

## Host facts

- Canonical workspace: `/workspace`
- Persistent state: `/workspace/.piclaw` and `/workspace/.pi`
- Never delete `/workspace/.piclaw/store/messages.db`
- `/workspace` is the canonical agent-facing path, but on this host it resolves through a symlink to `/home/agent/workspace`. When invoking Nix flakes directly with `path:` inputs, prefer the real `/home/agent/workspace/...` path if the `/workspace` form causes path-resolution issues.
- Do not create temporary worktrees just to dodge unrelated dirty files in `/workspace/src/pix` unless the user explicitly asks for that isolation or it is required for correctness.

Authoritative repos:
- `/workspace/src/pix` controls the NixOS host, Home Manager config, secrets, and `piclaw.service`.
- `/workspace/src/piclaw-customizations` controls the Piclaw prompt overlay, patches, extensions, and app deployment flow.

Deployment layout:
- `/workspace/src/piclaw-live` is the live checkout used by `piclaw.service`.
- `/workspace/src/piclaw-live.previous` is the rollback target from the last successful app update.
- `/workspace/src/piclaw-fork` is for clean upstream Piclaw work and PRs.
- `/workspace/.cache/piclaw-upstream` is the persistent upstream cache used by the update tooling.

Local deploy commands (declared in `pix/home/agent.nix`, installed under `~/.local/bin`):
- `rebuild` — start `pix-rebuild.service`, which pulls `/workspace/src/pix` and runs `nixos-rebuild switch --flake path:/home/agent/workspace/src/pix#pix`.
- `update [--force]` — start `piclaw-update.service` or `piclaw-update-force.service`.
- `rollback [--force]` — start `piclaw-rollback.service` or `piclaw-rollback-force.service`.
- `verify-deploy` — run `./scripts/piclaw-verify-deploy.sh` locally to validate a candidate Piclaw deploy without activating it.
- `piclaw-restart` — start `piclaw-restart.service`.
- `piclaw-status`, `piclaw-logs` — SSH wrappers for `systemctl status` / `journalctl -u piclaw` on the host.
- `host-result <unit>` — wait for a named host job unit and print its recent journal; use this after any queued job, especially jobs that may kill the current agent process.
- `backup` — start `restic-backups-r2.service`.
- `dependency-freshness` — check Nix flake/fetcher pins for minimum age and registry/API verification.
- `nfu` — update flake inputs and pinned package wrappers, then run freshness and package-build validation.

Shell aliases (bash): `sync-nix` = `rebuild`; `update-force` = `update --force`; `rollback-force` = `rollback --force`.

`rebuild`, `update`, `rollback`, `piclaw-restart`, and `backup` are asynchronous: they call `sudo systemctl start --no-block <unit>` for a fixed set of NixOS-declared oneshot units. Sudo is scoped to those exact start commands in `modules/host-jobs.nix`. Use `host-result <unit> --wait 900` to watch completion; for jobs that restart Piclaw, run `host-result piclaw-restart --wait 120` once the agent reconnects.

Prefer bounded log reads or periodic polling over indefinite `journalctl -f` when monitoring queued jobs. Use log-following only when it materially helps, and break out to report as soon as the user's question can be answered.

Do not assume upstream PiClaw deployment docs match this machine. Do not use upstream `docker-compose`, repo-install, supervisor, or bundled reload paths here unless the user explicitly asks for migration work.

The Piclaw service runs with `ProtectSystem=strict`. Host-level commands such as `nixos-rebuild` run through NixOS-declared oneshot units started by the `rebuild`/`update`/`rollback`/`piclaw-restart` helpers. Direct in-process `sudo nixos-rebuild` from inside the piclaw sandbox is not the supported path.

The Piclaw service PATH already includes `gh`, `git`, `patch`, `diff`, and `python3`. Host-side helpers use `/run/current-system/sw/bin/` and `/run/wrappers/bin/` when they need host-only tools or setuid wrappers.

See `/workspace/notes/reference/nixos-gotchas.md` for known NixOS-specific pitfalls (setuid wrappers, Playwright browsers, Bun global state, etc.).

## Browser verification

Use `agent-browser` for browser/UI verification. Start with `agent-browser skills get core --full` when command details are needed, then use `agent-browser open`, `snapshot`, `find`, `hover`, `click`, `screenshot`, and related commands for local app checks.

The deploy patch stack is verified and applied with strict `git apply`, not fuzzy GNU `patch`. Treat any `.rej` or `.orig` file in a candidate tree as leftover debris from an old or manual patch attempt.

When a UI-affecting change is deployed, prefer automated Playwright verification over manual screenshot exchange. The localhost E2E auth bootstrap endpoint exists for this purpose.

Do not open PRs without explicit user approval. Every PR must be tested via a full `update` cycle on the live host before submission.

Sign GitHub messages as `Pix (PiClaw, <MODEL_NAME>)`. Always call `get_model_state` to read the actual model string before signing.
