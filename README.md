# pix.mosphere.at

NixOS host for Piclaw on a Hetzner ARM64 VPS.

## Layout

- `flake.nix` — top-level flake
- `hosts/pix/default.nix` — host-specific config
- `disko/pix.nix` — disk layout
- `modules/` — service modules (base, tailscale, cloudflared, piclaw)
- `home/agent.nix` — Home Manager config for `agent`
- `scripts/deploy.sh` — `nixos-anywhere` install helper
- `scripts/prepare-bootstrap-key.sh` — generate/copy the host age key for first install
- `secrets/` — SOPS policy and encrypted secrets file

## Important defaults

- NixOS stable `25.11`
- latest Linux kernel via `boot.kernelPackages = pkgs.linuxPackages_latest`
- Piclaw is installed globally via bun by the `piclaw-customizations` repo
- workspace lives at `/home/agent/workspace` (symlinked as `/workspace`)
- Piclaw binds only to `127.0.0.1:8080`
- Cloudflare Tunnel publishes `pix.mosphere.at` (cloudflared runs as root with strict sandboxing)
- Tailscale is for admin access only
- public SSH is intentionally left open for the first deployment only

## What Nix manages vs. what it doesn't

Nix owns the **platform**: kernel, users, secrets, firewall, systemd service definition, env vars, directory structure.

Piclaw itself is an **application managed by the agent** via the separate [`piclaw-customizations`](https://github.com/aliceisjustplaying/piclaw-customizations) repo. That repo owns the update script, patches, extensions, and system prompt generation.

## After first deploy

- Verify Tailscale works
- Change `publicSshBootstrap = true;` to `false;` in `hosts/pix/default.nix`
- Run `rebuild` (alias for `sudo nixos-rebuild switch --flake ~/src/pix#pix`)
- Clone `piclaw-customizations` into `~/src/piclaw-customizations`
- Run the update script from that repo to install Piclaw
- Re-auth `claude` and `codex` as the `agent` user
- Open `https://pix.mosphere.at`, complete TOTP bootstrap, then enroll passkeys
