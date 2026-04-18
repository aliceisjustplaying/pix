# Vibes on `pix`

This host runs a second local web UI alongside PiClaw:

- PiClaw: `127.0.0.1:8080` -> `https://pix.mosphere.at`
- Vibes: `127.0.0.1:8081` -> `https://vibes.mosphere.at`

The Vibes instance is single-user, bound to localhost, and backed by Codex through ACP.

## What Nix manages

Repo-managed pieces:

- `modules/vibes.nix` defines `systemd.services.vibes`
- `pkgs/vibes.nix` packages upstream `rcarmo/vibes` `0.6.12`
- `pkgs/codex-acp.nix` packages `zed-industries/codex-acp` `0.11.1`
- `home/agent.nix` installs `vibes` and `codex-acp` into the `agent` profile
- `hosts/pix/default.nix` imports the Vibes module

Service defaults:

- `VIBES_HOST=127.0.0.1`
- `VIBES_PORT=8081`
- `VIBES_DB_PATH=/workspace/.pi/vibes/vibes.db`
- `VIBES_AGENT_NAME=Codex`
- `VIBES_ACP_AGENT=${codex-acp}/bin/codex-acp`
- working directory `/workspace`

Runtime state lives under `/workspace/.pi/vibes`.

## Packaging notes

### `codex-acp`

The packaged adapter uses the upstream Linux ARM64 release tarball. That was simpler and more reliable here than carrying a local Rust build for the whole workspace.

### `vibes`

Upstream `vibes` `0.6.12` builds against Nixpkgs Python with relaxed dependency pins for:

- `aiosqlite`
- `pillow`
- `python-dotenv`
- `watchfiles`

The package also carries a local `postPatch` for ACP model-picker support.

## ACP model picker fix

Upstream `vibes` `0.6.12` handled model discovery and switching through Pi RPC only. In ACP mode that left:

- `GET /agent/models` returning `{"current": null, "models": []}`
- the web model picker empty
- `/model`, `/cycle-model`, `/thinking`, and `/cycle-thinking` effectively Pi-only

The local patch in `pkgs/vibes.nix` fixes that for Codex ACP by:

- caching `session/new` and `session/set_config_option` ACP metadata
- exposing ACP-backed model and reasoning state through `/agent/models`
- wiring slash commands to ACP `session/set_config_option`
- reporting model/thinking changes back to the frontend in the same shape the UI already expects

This is intentionally a local patch against upstream `0.6.12`, not a forked repo checkout.

## Cloudflare publication

The repo only manages the local service. Publishing `vibes.mosphere.at` also required a manual Cloudflare Tunnel update outside this repo:

- add ingress for `vibes.mosphere.at` -> `http://localhost:8081`
- keep the existing `pix.mosphere.at` ingress -> `http://localhost:8080`
- add proxied DNS `CNAME` for `vibes.mosphere.at` pointing at the tunnel hostname

If Vibes is healthy locally but unreachable externally, check the tunnel ingress and DNS first.

## Deploy and verify

Rebuild the host in the normal way:

```bash
host-queue vibes-update 'sudo nixos-rebuild switch --flake path:/home/agent/workspace/src/pix#pix'
host-follow vibes-update-<epoch>
```

Useful checks:

```bash
curl -s http://127.0.0.1:8081/health
curl -s http://127.0.0.1:8081/agent/models
curl -s https://vibes.mosphere.at/agent/models
systemctl status vibes.service
```

Expected `/agent/models` shape in ACP mode:

```json
{
  "current": "gpt-5.4",
  "models": ["gpt-5.4", "gpt-5.4-mini", "..."],
  "thinking_level": "high",
  "supports_thinking": true
}
```

## Known behavior

- Vibes is still a single configured backend on this host: Codex only.
- Model changes happen within the active ACP session and do not require restarting `vibes.service`.
- The service is local-only; Cloudflare is the public entrypoint.
