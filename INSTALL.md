# A-to-Z install runbook for `pix2`

This assumes:

- Hetzner Cloud x86_64 VPS
- one disk
- current temporary image is any SSH-reachable Linux install
- you are running the install from a Mac
- Cloudflare manages `mosphere.at`
- Tailscale tag is `tag:pix`

## Prerequisites on the Mac

- Nix (Determinate installer): `curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install`
- Homebrew packages: `brew install age jq sops`
- `hcloud` CLI authenticated with your Hetzner project
- `gh` CLI authenticated with the GitHub account that owns the repo

## Create the Hetzner server

```bash
hcloud server create \
  --name pix2 \
  --type cpx42 \
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

Required secrets: `tailscale-auth-key`, `cloudflared-tunnel-token`, `piclaw-keychain-key`, `piclaw-web-totp-secret`, `piclaw-web-internal-secret`, `exa-api-key`, `github-clone-key`, `alice-cloudflare`, `restic-password`, `r2-access-key-id`, `r2-secret-access-key`. See `SECRETS-CHECKLIST.md` for how to generate each one.

**Back up both age keys** (`~/.config/sops/age/keys.txt` and `secrets/age/pix2-host.key`) to a password manager. These cannot be recovered.

## Lock flake inputs

```bash
nix flake lock
```

## Set up Cloudflare Tunnel routing (one-time)

Load the Cloudflare fields from SOPS:

```bash
CF_EMAIL="$(sops --decrypt --extract '["alice-cloudflare"]["email"]' secrets/secrets.yaml)"
CF_GLOBAL_KEY="$(sops --decrypt --extract '["alice-cloudflare"]["global-key"]' secrets/secrets.yaml)"
CF_ACCOUNT_ID="$(sops --decrypt --extract '["alice-cloudflare"]["account-id"]' secrets/secrets.yaml)"
CF_ZONE_ID="$(sops --decrypt --extract '["alice-cloudflare"]["zone-id"]' secrets/secrets.yaml)"
CF_TUNNEL_ID="$(sops --decrypt --extract '["cloudflared-tunnel-token"]' secrets/secrets.yaml | base64 -D | jq -r '.t')"
```

Add the ingress rule via API:

```bash
curl -X PUT "https://api.cloudflare.com/client/v4/accounts/${CF_ACCOUNT_ID}/cfd_tunnel/${CF_TUNNEL_ID}/configurations" \
  -H "X-Auth-Email: ${CF_EMAIL}" \
  -H "X-Auth-Key: ${CF_GLOBAL_KEY}" \
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

Add or update the DNS CNAME:

```bash
curl -X POST "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records" \
  -H "X-Auth-Email: ${CF_EMAIL}" \
  -H "X-Auth-Key: ${CF_GLOBAL_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"type\":\"CNAME\",\"name\":\"pix\",\"content\":\"${CF_TUNNEL_ID}.cfargotunnel.com\",\"proxied\":true}"
```

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

`piclaw.service` will not start yet - that's expected. It waits for `/workspace/src/piclaw-live/runtime/src/index.ts`, which does not exist until the first Piclaw update.

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
update --force
host-result piclaw-update-force.service --wait 900
```

Verify:

```bash
systemctl status piclaw.service --no-pager
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

Edit the relevant SSH/firewall settings in `/workspace/src/pix`, then:

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
update
host-result piclaw-update.service --wait 900
```

Use `update --force` to queue `piclaw-update-force.service`.

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
