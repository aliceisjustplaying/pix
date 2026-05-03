#!/usr/bin/env bash
set -euo pipefail
exec @home@/.local/bin/host-queue piclaw-restart "sleep 2; sudo systemctl restart piclaw"
