#!/usr/bin/env bash
set -euo pipefail
exec @home@/.local/bin/host-queue \
  pix-backup \
  "sudo systemctl start restic-backups-r2.service"
