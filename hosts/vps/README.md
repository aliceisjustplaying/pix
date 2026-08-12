# `vps` restore notes

This is the minimal `aarch64-linux` target for Plausible and the Song of Songs bot.

## Installed state

- The `nixos-anywhere` takeover completed on 2026-08-12. The host runs NixOS
  26.05 on `aarch64-linux`; Debian was erased.
- The Hetzner server remains a `cax21`. Its 75 GB system disk is `/dev/sda`;
  the old 150 GB `jetstream` volume was detached and deleted.
- SSH uses `agent@vps.bsky.sh` with `~/.ssh/pix`; direct root login is disabled.
- The final Song of Songs `posted.txt` history was restored with mode `0600`.
- The two Plausible instances were merged on 2026-08-12. `p.mosphere.at`
  points here, and Plausible is stopped and declaratively disabled on `pix2`.
- A synthetic taper-calculator pageview reached this host on 2026-08-12,
  increasing the merged totals to 105,500 events and 10,750 sessions.
- The merged, restore-tested backup is under
  `/Users/sarah/Backups/plausible-migration-2026-08-12`.

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

## Plausible recovery order

1. Stop Plausible while restoring PostgreSQL and ClickHouse.
2. Restore `merged/postgresql/merged-plausible.dump` and the three Native
   ClickHouse streams from the migration backup.
3. Verify six sites, 105,499 event rows, and 10,749 session rows before
   starting Plausible.
4. Verify HTTPS and `/js/script.js` after starting Caddy and Plausible.

The bot service has a `ConditionPathExists` gate and cannot post until `posted.txt` is restored.
