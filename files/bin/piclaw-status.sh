#!/usr/bin/env bash
set -euo pipefail
exec ssh -o BatchMode=yes localhost "systemctl status tailscaled cloudflared piclaw --no-pager"
