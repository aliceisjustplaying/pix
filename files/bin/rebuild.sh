#!/usr/bin/env bash
set -euo pipefail
unit="pix-rebuild.service"
sudo systemctl start --no-block "$unit"
printf 'queued %s\n' "$unit"
printf 'watch live logs with: journalctl -fu %s\n' "$unit"
printf 'check detached result with: host-result %s --wait 900\n' "$unit"
