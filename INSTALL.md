# A-to-Z install runbook for `pix.mosphere.at`

This assumes:

- Hetzner Cloud ARM64 VPS (CAX21 recommended)
- one disk
- current temporary image is any SSH-reachable Linux install
- you are running the install from a Mac
- Cloudflare manages `mosphere.at`
- Tailscale tag is `tag:pix`

## Prerequisites on the Mac

- Nix (Determinate installer): `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
- Homebrew packages: `brew install age sops`
- `hcloud` CLI authenticated with your Hetzner project
- `gh` CLI authenticated with the GitHub account that owns the repo

## Create the Hetzner server

```bash
hcloud server create \
  --name pix \
  --type cax21 \
  --image ubuntu-24.04 \
  --location fsn1 \
  --ssh-key <your-ssh-key-name>
```

SSH to verify the disk name if needed:

```bash
ssh root@<SERVER_IP> 'lsblk -o NAME,SIZE,TYPE,MOUNTPOINT'
```

If the main disk is not `/dev/sda`, edit `disko/pix.nix` and change the `device` value.

## Prepare secrets (if starting fresh)

Generate the age keys:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
./scripts/prepare-bootstrap-key.sh
```

Create `.sops.yaml` at the repo root with both public recipients (operator + host).

Create and encrypt `secrets/secrets.yaml`:

```bash
sops secrets/secrets.yaml
```

Required secrets: `tailscale-auth-key`, `cloudflared-tunnel-token`, `piclaw-keychain-key`, `piclaw-web-totp-secret`, `piclaw-web-internal-secret`, `exa-api-key`, `github-clone-key`, `cloudflare-api-token`, `restic-password`, `r2-access-key-id`, `r2-secret-access-key`. See `SECRETS-CHECKLIST.md` for how to generate each one.

**Back up both age keys** (`~/.config/sops/age/keys.txt` and `secrets/age/pix-host.key`) to a password manager. These cannot be recovered.

## Lock flake inputs

```bash
nix flake lock
```

## Set up Cloudflare Tunnel routing (one-time)

Add the ingress rule via API (replace token, account ID, and tunnel ID):

```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/<ACCOUNT_ID>/cfd_tunnel/<TUNNEL_ID>/configurations" \
  -H "Authorization: Bearer <CLOUDFLARE_API_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{
    "config": {
      "ingress": [
        {"hostname": "pix.mosphere.at", "service": "http://localhost:8080"},
        {"service": "http_status:404"}
      ]
    }
  }'
```

Add or update the DNS CNAME (find the zone ID first with `curl ... /zones?name=mosphere.at`):

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/<ZONE_ID>/dns_records" \
  -H "Authorization: Bearer <CLOUDFLARE_API_TOKEN>" \
  -H "Content-Type: application/json" \
  -d '{"type":"CNAME","name":"pix","content":"<TUNNEL_ID>.cfargotunnel.com","proxied":true}'
```

The tunnel ID and account ID can be extracted from the tunnel token: `echo '<token>' | base64 -d`.

## Deploy NixOS

```bash
./scripts/deploy.sh <SERVER_IP>
```

This runs `nixos-anywhere` which boots a kexec NixOS installer, partitions the disk, builds the system on the server, deploys the bootstrap age key, and reboots into NixOS. Takes 10-20 minutes on a CAX21.

## First login after reboot

```bash
ssh agent@<SERVER_IP>
```

If using Ghostty, set `export TERM=xterm-256color` until the first rebuild installs full terminfo.

Check services:

```bash
systemctl status tailscaled tailscaled-autoconnect cloudflared --no-pager
sudo tailscale status
```

`piclaw.service` will not start yet — that's expected. It waits for `/usr/local/bin/piclaw` which doesn't exist until the first update.

## Clone repos on the server

The pix repo is public, so use HTTPS (the GitHub SSH key isn't available until after the first rebuild):

```bash
mkdir -p /workspace/src
cd /workspace/src
git clone https://github.com/<YOU>/pix.git
cd pix && rebuild
```

After rebuild, sops secrets are decrypted and the GitHub SSH key works:

```bash
mkdir -p /workspace/src
cd /workspace/src
git clone git@github.com:<YOU>/piclaw-customizations.git
git clone git@github.com:<YOU>/piclaw.git piclaw-fork
cd piclaw-fork
git remote add upstream https://github.com/rcarmo/piclaw.git
cd ..
```

Then switch the pix remote to SSH for future pushes:

```bash
cd /workspace/src/pix && git remote set-url origin git@github.com:<YOU>/pix.git
```

## First Piclaw install

Deploy the first live checkout and start the service from source:

```bash
cd /workspace/src/piclaw-customizations
./scripts/piclaw-update.sh --force
```

Verify:

```bash
systemctl status piclaw --no-pager
curl -s http://localhost:8080 | head -5
```

## Re-auth Claude and Codex

As `agent`:

```bash
claude
codex
```

Complete their login flows manually.

## Log in and enroll passkeys

- Open `https://pix.mosphere.at`
- Add the `piclaw-web-totp-secret` to your authenticator app (get it with `sudo cat /run/secrets/piclaw-web-totp-secret`)
- Log in with the 6-digit TOTP code
- In the chat input, type `/passkey enrol`
- Open the enrollment link in the same browser and register your passkey
- After enrollment, login is passkey-only

## Disable public SSH

After Tailscale SSH works and you can still reach the box:

Edit `/workspace/src/pix/hosts/pix/default.nix`, change `publicSshBootstrap = true` to `false`, then:

```bash
rebuild
```

After that, TCP/22 is only allowed on the Tailscale interface.

## Day-2 operations

### Rebuild host config

```bash
rebuild
```

### Update Piclaw

```bash
cd /workspace/src/piclaw-customizations
./scripts/piclaw-update.sh
```

Use `--force` to skip version check, `--dry-run` to compare versions without installing, `--no-restart` if the caller handles restart.

Host-level helper tooling now includes:

- `chromium` for Playwright/browser validation
- `zig` for rebuilding `ghostty-web` wasm artifacts when a forked/vendor patch needs a fresh `ghostty-vt.wasm`

### Work on upstream Piclaw PRs

Use the dedicated fork checkout, not the deployment checkout:

```bash
cd /workspace/src/piclaw-fork
git fetch upstream
git switch main
git reset --hard upstream/main
git switch -c <branch-name>
```

`/workspace/src/piclaw-live` is reserved for the running service and local patch-stack validation.

### Roll back Piclaw

```bash
rollback
```

This swaps `/workspace/src/piclaw-live.previous` back into place and restarts the service. The first source-run deployment has no rollback target yet; rollback becomes available after the next successful update.

### Update Claude Code and Codex CLI

These are managed as Nix flake inputs:

```bash
cd /workspace/src/pix
nix flake update claude-code codex-cli
git add flake.lock && git commit -m "Update claude-code and codex-cli"
rebuild
```

### Update all Nix inputs (nixpkgs, home-manager, etc.)

```bash
cd /workspace/src/pix
nix flake update
git add flake.lock && git commit -m "Update flake inputs"
rebuild
```

This includes kernel updates. The new kernel takes effect on next reboot.

### Enable Hetzner automatic backups

```bash
hcloud server enable-backup <SERVER_ID>
```

### Manual restic backup

```bash
sudo systemctl start restic-backups-r2.service
sudo journalctl -u restic-backups-r2.service --no-pager
```

### List restic snapshots

The restic password is in SOPS. Export it first, then query:

```bash
sudo restic -r s3:https://b752c979e541327de3e87e52f0906aa1.r2.cloudflarestorage.com/pix-backup snapshots
```

### Resize the server

In `hcloud` or the Hetzner dashboard, you can upgrade CPU/RAM without expanding the disk. This lets you downgrade later. If you expand the disk, the upgrade is permanent.
