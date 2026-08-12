# `vps` restore notes

This is the minimal `aarch64-linux` target for Plausible and the Song of Songs bot. `pix2` remains the source of truth for the taper-calculator Plausible data until the final restore and cutover are verified.

## Before installation

1. Keep `/Users/sarah/Backups/vps.bsky.sh-2026-08-12` and its checksums available.
2. Power on the existing Debian server. No provider reimage is needed:
   `nixos-anywhere` kexecs its installer and Disko replaces Debian with a clean
   NixOS filesystem. The Hetzner server type and billing tier are unchanged.
3. Confirm the remaining 75 GB system disk is `/dev/sda` with `lsblk` before
   running Disko. The old 150 GB `jetstream` volume was detached and deleted
   on 2026-08-12.
4. Prepare the ignored bootstrap key directory:

   ```bash
   ./scripts/prepare-bootstrap-key.sh \
     secrets/age/vps-host.key \
     .nixos-anywhere-extra-vps
   ```

5. Run the takeover install against the existing server:

   ```bash
   ./scripts/deploy.sh --host vps <server-ip>
   ```

## Restore order

1. Leave `p.mosphere.at` pointed at `pix2` while restoring.
2. Stop Plausible, PostgreSQL, ClickHouse, Caddy, and `songofsongs.timer` on the new host.
3. Restore and merge the Plausible PostgreSQL and ClickHouse backups, then verify all sites and the taper calculator.
4. Restore the final `posted.txt` to `/var/lib/songofsongs/posted.txt` with owner `songofsongs:songofsongs` and mode `0600`.
5. Start Plausible and verify HTTPS/tracking, validate the bot credentials
   without starting its timer, then move DNS.

The bot service has a `ConditionPathExists` gate and cannot post until `posted.txt` is restored.
