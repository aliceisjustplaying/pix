# `vps` restore notes

This is the minimal `aarch64-linux` target for Plausible and the Song of Songs bot. `pix2` remains the source of truth for the taper-calculator Plausible data until the final restore and cutover are verified.

## Installed state

- The `nixos-anywhere` takeover completed on 2026-08-12. The host runs NixOS
  26.05 on `aarch64-linux`; Debian was erased.
- The Hetzner server remains a `cax21`. Its 75 GB system disk is `/dev/sda`;
  the old 150 GB `jetstream` volume was detached and deleted.
- SSH uses `agent@vps.bsky.sh` with `~/.ssh/pix`; direct root login is disabled.
- The final Song of Songs `posted.txt` history was restored with mode `0600`.
- Keep `/Users/sarah/Backups/vps.bsky.sh-2026-08-12` and its checksums until
  the Plausible merge and cutover are verified.

For a future reinstall, prepare the ignored bootstrap key directory:

```bash
./scripts/prepare-bootstrap-key.sh \
  secrets/age/vps-host.key \
  .nixos-anywhere-extra-vps
```

Then run:

```bash
./scripts/deploy.sh --host vps <server-ip>
```

## Restore order

1. Leave `p.mosphere.at` pointed at `pix2` while restoring.
2. Stop Plausible, PostgreSQL, ClickHouse, Caddy, and `songofsongs.timer` on the new host.
3. Restore and merge the Plausible PostgreSQL and ClickHouse backups, then verify all sites and the taper calculator.
4. The final `posted.txt` is already restored to `/var/lib/songofsongs/posted.txt`.
5. Start Plausible and verify HTTPS/tracking, validate the bot credentials
   without starting its timer, then move DNS.

The bot service has a `ConditionPathExists` gate and cannot post until `posted.txt` is restored.
