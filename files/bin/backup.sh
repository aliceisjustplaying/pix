#!/usr/bin/env bash
set -euo pipefail
exec ssh -o BatchMode=yes localhost "sudo systemctl start restic-backups-r2.service && sudo journalctl -u restic-backups-r2.service --no-pager -f"
