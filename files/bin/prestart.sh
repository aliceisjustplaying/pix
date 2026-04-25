#!/usr/bin/env bash
set -euo pipefail
exec @home@/.local/bin/host-queue piclaw-restart "sudo systemctl restart piclaw"
