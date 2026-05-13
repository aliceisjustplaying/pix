# pix-amd64 migration runbook

Target: netcup RS 2000 G12, `x86_64-linux`, NixOS flake target `.#pix-amd64`.

The current ARM host remains `.#pix`. Do not run `nixos-rebuild switch --flake .#pix-amd64` on the current host.

## Repo preflight

Run from `/workspace/src/pix` before touching the new server:

```bash
git status -sb
git diff --name-status
nix eval .#nixosConfigurations.pix.config.system.build.toplevel.drvPath --raw
nix eval .#nixosConfigurations.pix-amd64.config.system.build.toplevel.drvPath --raw
shellcheck scripts/deploy.sh files/host-jobs/pix-rebuild.sh files/bin/nfu.sh
git diff --check
```

Expected:

- `.#pix` still evaluates as the current ARM host.
- `.#pix-amd64` evaluates as the new x86_64 host.
- Only intentional migration files are dirty.

## New server preflight

Boot the netcup server into rescue or the temporary installer, then check:

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
ip addr
ip route
```

Expected:

- main disk is `/dev/vda`; if not, update `hosts/pix-amd64/default.nix`
- network is reachable over SSH as `root`
- no persistent data on the target disk

## SOPS recipient

Create the new host age key and nixos-anywhere extra files before deployment:

```bash
scripts/prepare-bootstrap-key.sh secrets/age/pix-amd64-host.key
```

Add the printed public key as a third recipient in `.sops.yaml`, then rekey:

```bash
sops updatekeys secrets/secrets.yaml
```

Keep the old `pix` recipient during migration. Remove it only after cutover and rollback window.

The private key and `.nixos-anywhere-extra` are gitignored. Do not commit them.

## Install pix-amd64

From this repo:

```bash
scripts/deploy.sh --host pix-amd64 <server-ip>
```

After the first boot:

```bash
ssh agent@<server-ip> 'hostnamectl --static && uname -m'
ssh agent@<server-ip> 'systemctl --no-pager --failed'
ssh agent@<server-ip> 'sudo systemctl start --no-block pix-rebuild.service'
ssh agent@<server-ip> 'host-result pix-rebuild --wait 3600 --tail 80'
```

Expected:

- hostname is `pix-amd64`
- architecture is `x86_64`
- `pix-rebuild.service` rebuilds `.#pix-amd64`

## Restore preflight

Before copying or restoring state:

```bash
ssh agent@<server-ip> 'tailscale status'
ssh agent@<server-ip> 'systemctl status cloudflared --no-pager'
ssh agent@<server-ip> 'sudo systemctl start --no-block restic-backups-r2.service'
ssh agent@<server-ip> 'host-result restic-backups-r2 --wait 900 --tail 80'
```

Confirm the R2 restic repository is readable before relying on it for rollback.

## State to migrate

Minimum agent runner state:

- `/workspace`
- `/home/agent/.ssh` if not fully generated from SOPS
- `/home/agent/.claude`, `/home/agent/.codex`, `/home/agent/.factory` if sessions/config must carry over

Full service state:

- `/workspace`
- Plausible PostgreSQL database
- ClickHouse database for Plausible events
- Caddy state if avoiding new ACME issuance
- Tailscale identity only if preserving the same tailnet machine identity; otherwise authenticate as a new host

Do not cut DNS or Cloudflare tunnel traffic until the new host has restored state and passed service checks.

## Cutover checks

Before switching traffic:

```bash
ssh agent@<server-ip> 'systemctl status piclaw hermes-gateway plausible caddy cloudflared --no-pager'
ssh agent@<server-ip> 'curl -fsS http://127.0.0.1:8000/api/health || true'
ssh agent@<server-ip> 'curl -fsS http://127.0.0.1:2019/config/ >/dev/null || true'
ssh agent@<server-ip> 'df -h / /workspace'
```

Then update DNS/tunnel routing, wait for traffic, and keep the old `pix` host running.

## Rollback

Rollback is DNS/tunnel reversal while the old host remains online.

Keep the old host unchanged until:

- the new host has completed a backup
- Plausible data is present after cutover
- Piclaw and Hermes have survived at least one restart
- no missing state is found in `/workspace`

After the rollback window, remove the old `pix` SOPS recipient and re-run `sops updatekeys secrets/secrets.yaml`.
