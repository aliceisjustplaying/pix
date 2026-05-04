#!/usr/bin/env bash
set -euo pipefail
unit="piclaw-restart.service"
sudo systemctl start --no-block "$unit"
printf 'queued %s\n' "$unit"
printf 'check detached result with: host-result %s --wait 120\n' "$unit"
