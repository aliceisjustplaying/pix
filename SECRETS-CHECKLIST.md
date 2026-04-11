# Secrets to collect before the first install

This is the separate prep list.
Everything below should exist **before** you run `./scripts/deploy.sh`.

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
ssh-keygen -t ed25519 -f ./github-clone-key -C "pix.mosphere.at"
```

Then:
- add `./github-clone-key.pub` to the GitHub account or machine user that should have repo access
- paste the **private** key into `secrets/secrets.yaml`

Where it goes:
- `secrets/secrets.yaml` under `github-clone-key`

### 8. `cloudflare-api-token`
What it is:
- a Cloudflare API token for DNS management from the server

How to create it:
- Cloudflare dashboard → My Profile → API Tokens → Create Token
- use "Create Custom Token"
- permissions: Account / Cloudflare Tunnel / Edit, Zone / DNS / Edit
- scope zone to `mosphere.at`

Where it goes:
- `secrets/secrets.yaml` under `cloudflare-api-token`

## Required bootstrap key material

### 9. Operator age key
What it is:
- the age key used on your Mac to edit and decrypt the SOPS file

Create it if needed:

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
age-keygen -y ~/.config/sops/age/keys.txt
```

Use the printed public recipient in `.sops.yaml` (at the repo root).

### 10. Host age key
What it is:
- the server-side age key that lets the fresh host decrypt `secrets/secrets.yaml` on first boot

How it is created:

```bash
./scripts/prepare-bootstrap-key.sh
```

This generates:
- `secrets/age/pix-host.key`
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
