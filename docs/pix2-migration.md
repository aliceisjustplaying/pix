# pix2 migration runbook

Target: Hetzner CPX42, `x86_64-linux`, NixOS flake target `.#pix2`.

The current ARM host remains `.#pix`. Do not run `nixos-rebuild switch --flake .#pix2` on the current host.

## Repo preflight

Run from `/workspace/src/pix` before touching the new server:

```bash
git status -sb
git diff --name-status
nix eval .#nixosConfigurations.pix.config.system.build.toplevel.drvPath --raw
nix eval .#nixosConfigurations.pix2.config.system.build.toplevel.drvPath --raw
shellcheck scripts/deploy.sh files/host-jobs/pix-rebuild.sh files/bin/nfu.sh
git diff --check
```

Expected:

- `.#pix` still evaluates as the current ARM host.
- `.#pix2` evaluates as the new x86_64 host.
- Only intentional migration files are dirty.

## New server preflight

Boot the Hetzner server into rescue or the temporary installer, then check:

```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
ip addr
ip route
```

Expected:

- main disk is `/dev/sda`; if not, update `disko/pix.nix` or add a host override in `hosts/pix2/default.nix`
- network is reachable over SSH as `root`
- no persistent data on the target disk

## SOPS recipient

Create the new host age key and nixos-anywhere extra files before deployment:

```bash
scripts/prepare-bootstrap-key.sh secrets/age/pix2-host.key
```

Add the printed public key as a third recipient in `.sops.yaml`, then rekey:

```bash
sops updatekeys secrets/secrets.yaml
```

Keep the old `pix` recipient during migration. Remove it only after cutover and rollback window.

The private key and `.nixos-anywhere-extra` are gitignored. Do not commit them.

## Install pix2

`pix2` boots in staging mode until cutover: only SSH is exposed publicly, and
production-facing services, tunnels, runners, cron jobs, backups, and Tailscale
are not wanted by `multi-user.target`. This lets the host build the full system
closure without publishing routes or touching shared production services.

From this repo:

```bash
scripts/deploy.sh --host pix2 <server-ip>
```

After the first boot:

```bash
ssh agent@<server-ip> 'hostnamectl --static && uname -m'
ssh agent@<server-ip> 'systemctl --no-pager --failed'
ssh agent@<server-ip> 'sudo systemctl start --no-block pix-rebuild.service'
ssh agent@<server-ip> 'host-result pix-rebuild --wait 3600 --tail 80'
```

Expected:

- hostname is `pix2`
- architecture is `x86_64`
- public listening sockets are limited to SSH
- Piclaw, Hermes, Caddy, Cloudflare Tunnel, Plausible, ClickHouse, runners, backups, cron, atd, and Tailscale are inactive
- `pix-rebuild.service` rebuilds `.#pix2`

To prebuild on `pix2` without starting the production stack:

```bash
ssh agent@<server-ip> 'cd /home/agent/workspace/src/pix && nixos-rebuild build --flake .#pix2'
```

Do not run `nixos-rebuild switch` with the production services enabled until
the final cutover window.

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

Goal: copy enough state that tools, auth, browser profiles, agents, Hermes,
Gog, Google, Claude, Codex, and service data keep working without manual
reauthentication.

Hermes state is split across:

- `/workspace/src/hermes-live` and `/workspace/src/hermes-webui` for source checkouts
- `/workspace/.hermes` for config, sessions, logs, skills, pairing, WebUI state, and overrides
- `/home/agent/.hindsight` for the Hindsight profile/config
- `/home/agent/.pg0/instances/hindsight-embed-hermes` for Hindsight's embedded PostgreSQL data
- `/home/agent/.cli-proxy-api` for the local OpenAI-compatible proxy config
- `/home/agent/.config/gogcli` and `/home/agent/.config/gogcli/keyring` for Gog account config and tokens
- `/home/agent/.agents`, `/home/agent/.codex`, `/home/agent/.claude`, and `/home/agent/.factory` for agent config and sessions

Do not copy architecture-specific generated artifacts from the ARM host:
Hermes venvs and pg0 PostgreSQL binaries must be rebuilt on `pix2`.

Before the final state copy, export Hindsight's database from the old host:

```bash
mkdir -p /home/agent/migration
old_hindsight_port="$(/workspace/.hermes/venv/lib/python3.12/site-packages/pg0/bin/pg0 info --name hindsight-embed-hermes -o json | jq -r .port)"
LD_LIBRARY_PATH="$(sudo sed -n 's/^LD_LIBRARY_PATH=//p' /run/secrets/rendered/hermes-service-env)" \
  PGPASSWORD=hindsight \
  /home/agent/.pg0/installation/18.1.0/bin/pg_dump \
    -h 127.0.0.1 \
    -p "$old_hindsight_port" \
    -U hindsight \
    -d hindsight \
    -Fc \
    -f /home/agent/migration/hindsight-hermes.dump
```

Use rsync from the old host to the new host after the new NixOS boot succeeds.
Stop the new host's services first so empty first-boot state does not race the
copy:

```bash
ssh agent@<server-ip> 'sudo systemctl stop hermes-gateway hermes-webui piclaw plausible postgresql clickhouse caddy cloudflared || true'
```

Copy the workspace and agent home. Keep generated caches out; keep auth,
config, session, browser, keyring, and memory state in:

```bash
rsync -aHAX --numeric-ids --info=progress2 \
  --exclude '/.cache/' \
  --exclude '/.nix-defexpr' \
  --exclude '/.nix-profile' \
  --exclude '/.npm/' \
  --exclude '/.pg0/installation/' \
  --exclude '/.pg0/instances/' \
  --exclude '/.cargo/registry/' \
  --exclude '/.bun/install/cache/' \
  --exclude '/workspace/.hermes/venv/' \
  --exclude '/workspace/src/*/node_modules/' \
  /home/agent/ root@<server-ip>:/home/agent/

rsync -aHAX --numeric-ids --info=progress2 \
  --exclude '/.hermes/venv/' \
  --exclude '/src/*/node_modules/' \
  /workspace/ root@<server-ip>:/workspace/
```

Copy service state that is outside `/home/agent` and `/workspace`:

```bash
rsync -aHAX --numeric-ids --info=progress2 /var/lib/postgresql/ root@<server-ip>:/var/lib/postgresql/
rsync -aHAX --numeric-ids --info=progress2 /var/lib/clickhouse/ root@<server-ip>:/var/lib/clickhouse/
rsync -aHAX --numeric-ids --info=progress2 /var/lib/caddy/ root@<server-ip>:/var/lib/caddy/
```

Do not copy `/var/lib/sops-nix/key.txt`; that must be the new `pix2` host key
that matches the SOPS recipient used for deployment.

For Tailscale, either use the SOPS auth key to register `pix2` as a new
tailnet node, or copy `/var/lib/tailscale` only during final cutover after
stopping `tailscaled` on the old host. Do not run two hosts with the same
Tailscale node identity.

After copying, fix ownership-sensitive service state and restart:

```bash
ssh agent@<server-ip> 'sudo chown -R agent:users /home/agent /workspace'
ssh agent@<server-ip> 'sudo systemctl restart postgresql clickhouse caddy cloudflared plausible piclaw hermes-gateway hermes-webui'
```

Once Hermes has started Hindsight on `pix2`, restore the Hindsight dump:

```bash
ssh agent@<server-ip> 'curl -fsS http://127.0.0.1:9177/health'
rsync -aHAX --info=progress2 /home/agent/migration/hindsight-hermes.dump root@<server-ip>:/home/agent/migration/
ssh agent@<server-ip> '
  new_hindsight_port="$(/workspace/.hermes/venv/lib/python3.12/site-packages/pg0/bin/pg0 info --name hindsight-embed-hermes -o json | jq -r .port)"
  LD_LIBRARY_PATH="$(sudo sed -n "s/^LD_LIBRARY_PATH=//p" /run/secrets/rendered/hermes-service-env)" \
    PGPASSWORD=hindsight \
    /home/agent/.pg0/installation/18.1.0/bin/pg_restore \
      --clean \
      --if-exists \
      -h 127.0.0.1 \
      -p "$new_hindsight_port" \
      -U hindsight \
      -d hindsight \
      /home/agent/migration/hindsight-hermes.dump
'
ssh agent@<server-ip> 'sudo systemctl restart hermes-gateway'
```

Do not cut DNS or Cloudflare tunnel traffic until the new host has restored
state and passed service checks.

## Cutover checks

Before switching traffic:

```bash
ssh agent@<server-ip> 'systemctl status piclaw hermes-gateway plausible caddy cloudflared --no-pager'
ssh agent@<server-ip> 'systemctl --user status cli-proxy-api --no-pager'
ssh agent@<server-ip> 'curl -fsS http://127.0.0.1:8084/ >/dev/null || true'
ssh agent@<server-ip> 'curl -fsS http://127.0.0.1:9177/health'
ssh agent@<server-ip> 'hermes memory status'
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
