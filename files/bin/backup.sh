#!/usr/bin/env bash
set -euo pipefail
unit="restic-backups-r2.service"
sudo systemctl start --no-block "$unit"
printf 'queued %s\n' "$unit"
printf 'check detached result with: host-result %s --wait 900\n' "$unit"
