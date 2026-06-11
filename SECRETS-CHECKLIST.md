# Secrets checklist

Collect everything below **before** running `./scripts/deploy.sh`.

## Required runtime secrets

### 1. `tailscale-auth-key`
What it is:
- a Tailscale auth key for this server

How to create it:
- Tailscale admin console → Keys → Generate auth key
- use a **tagged** key with `tag:pix`
- use a **reusable** (non-ephemeral) key — it needs to work across reboots and rebuilds

Where it goes:
- `secrets/secrets.yaml` under `tailscale-auth-key`

### 2. `cloudflared-tunnel-token`
What it is:
- the token for a **remotely-managed** Cloudflare Tunnel

How to create it:
- Cloudflare Zero Trust → Networks → Tunnels → Create tunnel → Cloudflared
- choose a remotely-managed tunnel
- copy the token

Where it goes:
- `secrets/secrets.yaml` under `cloudflared-tunnel-token`

### 3. `piclaw-keychain-key`
What it is:
- Piclaw keychain/state encryption key

How to create it:
- generate a strong random secret, for example:

```bash
openssl rand -hex 32
```

Where it goes:
- `secrets/secrets.yaml` under `piclaw-keychain-key`

### 4. `piclaw-web-totp-secret`
What it is:
- the bootstrap/recovery TOTP secret for Piclaw web auth

How to create it:
- generate a Base32 secret, for example:

```bash
python3 - <<'PY'
import base64, os
print(base64.b32encode(os.urandom(20)).decode().rstrip('='))
PY
```

Where it goes:
- `secrets/secrets.yaml` under `piclaw-web-totp-secret`

### 5. `piclaw-web-internal-secret`
What it is:
- the shared secret for Piclaw internal authenticated endpoints and automations

How to create it:

```bash
openssl rand -hex 32
```

Where it goes:
- `secrets/secrets.yaml` under `piclaw-web-internal-secret`

### 6. `exa-api-key`
What it is:
- the Exa API key used to generate `~/.pi/web-search.json`

Where to get it:
- your Exa account/dashboard

Where it goes:
- `secrets/secrets.yaml` under `exa-api-key`

### 7. `github-clone-key`
What it is:
- an SSH private key for the GitHub account or machine user that should be allowed to clone private repos from this host

Important:
- this is better thought of as a **GitHub machine key** than a single-repo deploy key
- if the host needs access to more than one private repo, attach the public key to a GitHub account or machine user that has the correct repo access

How to create it:

```bash
ssh-keygen -t ed25519 -f ./github-clone-key -C "pix2"
```

Then:
- add `./github-clone-key.pub` to the GitHub account or machine user that should have repo access
- paste the **private** key into `secrets/secrets.yaml`

Where it goes:
- `secrets/secrets.yaml` under `github-clone-key`

### 8. `gog-oauth-client-json`
What it is:
- the OAuth Desktop client JSON downloaded from Google Cloud for Gog

Where it goes:
- `secrets/secrets.yaml` under `gog-oauth-client-json`
- rendered by `agent-secrets.service` to `/home/agent/.config/gog/oauth-client.json`

Import:

```bash
jq -Rs . /path/to/client_secret.json |
  sops set --value-stdin secrets/secrets.yaml '["gog-oauth-client-json"]'
```

### 9. `gog-keyring-password`
What it is:
- the password for Gog's file keyring backend

Where it goes:
- `secrets/secrets.yaml` under `gog-keyring-password`
- rendered into `hermes-gateway.service` as `GOG_KEYRING_PASSWORD`

Import:

```bash
jq -Rs . /home/agent/.config/gogcli/keyring-password |
  sops set --value-stdin secrets/secrets.yaml '["gog-keyring-password"]'
```

### 10. `alice-cloudflare`
What it is:
- Cloudflare Global API Key access data for `aliceisjustplaying@gmail.com`
- this is account-wide and cannot be permission-scoped inside Cloudflare
- stored for manual/emergency use; it is not rendered into service environments

Fields:
- `email`
- `account-id`
- `zone-id`
- `global-key`

Where it goes:
- `secrets/secrets.yaml` under `alice-cloudflare`

### Local-only: Bluepy GitHub runner token
What it is:
- a fine-grained GitHub PAT used only to register the `bluepy-agent` self-hosted runner

Required access:
- repository: `aliceisjustplaying/bluepy`
- permission: read/write access to repository self-hosted runners

Where it goes:
- `/home/agent/.config/github-runner/bluepy-token` on the VPS
- one line, no trailing newline

Install:

```bash
install -d -m 700 /home/agent/.config/github-runner
printf '%s' '<token>' > /home/agent/.config/github-runner/bluepy-token
chown -R agent:users /home/agent/.config/github-runner
chmod 600 /home/agent/.config/github-runner/bluepy-token
sudo systemctl restart github-runner-bluepy-agent-{1,2,3}.service
```

### 12. `restic-password`
What it is:
- the encryption password for the restic backup repository on Cloudflare R2

How to create it:

```bash
openssl rand -hex 32
```

Where it goes:
- `secrets/secrets.yaml` under `restic-password`

**Back this up** to a password manager. Without it, backups cannot be restored.

### 13. `r2-access-key-id`
What it is:
- the S3-compatible Access Key ID for the Cloudflare R2 backup bucket

How to create it:
- Cloudflare dashboard → R2 → Manage R2 API Tokens → Create API token
- permission: Object Read & Write
- scope: `pix-backup` bucket only

Where it goes:
- `secrets/secrets.yaml` under `r2-access-key-id`

### 14. `r2-secret-access-key`
What it is:
- the S3-compatible Secret Access Key paired with the R2 Access Key ID above

How to create it:
- created at the same time as `r2-access-key-id`

Where it goes:
- `secrets/secrets.yaml` under `r2-secret-access-key`

### 15. `todoist-api-token`
What it is:
- the Todoist API token for CLI/API access

Where it goes:
- `secrets/secrets.yaml` under `todoist-api-token`

## Required bootstrap key material

### 16. Operator age key
What it is:
- the age key used on your Mac to edit and decrypt the SOPS file

Create it if needed:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

Use the printed public recipient in `.sops.yaml` (at the repo root).

### 17. Host age key
What it is:
- the server-side age key that lets the fresh host decrypt `secrets/secrets.yaml` on first boot

How it is created:

```bash
./scripts/prepare-bootstrap-key.sh
```

This generates:
- `secrets/age/pix2-host.key`
- `./.nixos-anywhere-extra/var/lib/sops-nix/key.txt`

Use the printed public recipient in `.sops.yaml` (at the repo root).

## Not needed for this install

These often get mixed in by accident.
They are **not** required for the host runtime secrets file unless you later automate those systems from the VPS itself.

- Hetzner API token
- Cloudflare global API key
- Claude session files
- Codex session files

Claude and Codex should be re-authenticated manually on the new host.

## Plain config that is intentionally not a secret

These are configured in Nix, not SOPS:

- hostname `pix.mosphere.at`
- Piclaw bind host `127.0.0.1`
- Piclaw port `8080`
- `PICLAW_TRUST_PROXY=1`
- `PICLAW_WEB_TERMINAL_ENABLED=1`
- `PICLAW_WEB_PASSKEY_MODE=passkey-only`
- `PICLAW_DREAM_MODEL=anthropic/claude-sonnet-4-6`
- Tailscale tag `tag:pix`

## emojistats (hosts: emoji, crawl0..5)

- `emojistats-env` — env file for the serving services (ingest/api/dashboard/rebuild on `emoji`):
  ```
  CLICKHOUSE_URL=http://127.0.0.1:8123
  CLICKHOUSE_DATABASE=emojistats
  CLICKHOUSE_USER=emojistats
  CLICKHOUSE_PASSWORD=<generate>
  JETSTREAM_ENDPOINT=wss://jetstream2.us-east.bsky.network/subscribe
  ORIGINS=https://emojitracker.bsky.sh
  ```
- `emojistats-clickhouse-users.xml` — ClickHouse users.d drop-in creating the `emojistats` user; hash via `echo -n '<password>' | shasum -a 256`:
  ```xml
  <clickhouse>
    <users>
      <emojistats>
        <password_sha256_hex>HASH</password_sha256_hex>
        <networks><ip>::/0</ip></networks>
        <profile>default</profile>
        <quota>default</quota>
      </emojistats>
    </users>
  </clickhouse>
  ```
  (networks stays wide because the firewall only exposes 8123 on the tailnet)
- `emojistats-crawl-env` — env file for the crawl boxes; same keys as `emojistats-env` but `CLICKHOUSE_URL=http://emoji:8123` (tailnet MagicDNS name), plus optional per-box overrides (GLOBAL_CONCURRENCY etc. — EnvironmentFile wins over module defaults)
- `emojistats-rclone-conf` — rclone config with the Storage Box remote:
  ```ini
  [storagebox]
  type = sftp
  host = <uXXXXXX>.your-storagebox.de
  user = <uXXXXXX>
  pass = <rclone obscure'd password>
  shell_type = unix
  ```
