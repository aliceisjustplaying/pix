# Vibes on `pix`

This host runs a second local web UI alongside PiClaw:

- PiClaw: `127.0.0.1:8080` -> `https://pix.mosphere.at`
- Vibes: `0.0.0.0:8081`, reachable only through Tailscale

The Vibes instance is single-user, backed by Codex through ACP, and intentionally not published on the public internet.

## What Nix manages

Repo-managed pieces:

- `modules/vibes.nix` defines `systemd.services.vibes`
- `pkgs/vibes.nix` packages upstream `rcarmo/vibes` `0.6.12`
- `pkgs/codex-acp.nix` packages `zed-industries/codex-acp` `0.12.0`
- `home/agent.nix` installs `vibes` and `codex-acp` into the `agent` profile
- `hosts/pix/default.nix` imports the Vibes module

Service defaults:

- `VIBES_HOST=0.0.0.0`
- `VIBES_PORT=8081`
- `VIBES_DB_PATH=/workspace/.pi/vibes/vibes.db`
- `VIBES_AGENT_NAME=Codex`
- `VIBES_ACP_AGENT=${codex-acp}/bin/codex-acp`
- working directory `/workspace`

Network policy:

- `networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 8081 ]`
- no public firewall opening for `8081`

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

## Access model

Vibes is not password-protected by upstream default. The stock auth middleware is a no-op unless a custom callback is wired in, so this host treats network isolation as the control boundary.

Because of that, the service is tailscale-only:

- Vibes listens on `8081`
- the firewall only permits that port on `tailscale0`
- the previous Cloudflare publication for `vibes.mosphere.at` should remain removed

Use one of:

- `http://100.74.251.100:8081`
- `http://pix:8081` if MagicDNS is enabled in the tailnet

## Deploy and verify

Rebuild the host in the normal way:

```bash
host-queue vibes-update 'sudo nixos-rebuild switch --flake path:/home/agent/workspace/src/pix#pix'
host-follow vibes-update-<epoch>
```

Useful checks:

```bash
curl -s http://127.0.0.1:8081/health
curl -s http://100.74.251.100:8081/health
curl -s http://100.74.251.100:8081/agent/models
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
- The service is tailscale-only; there is no intended public hostname.
