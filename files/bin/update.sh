#!/usr/bin/env bash
set -euo pipefail
case "$*" in
"")
	unit="piclaw-update.service"
	;;
"--force")
	unit="piclaw-update-force.service"
	;;
*)
	echo "usage: update [--force]" >&2
	exit 64
	;;
esac
sudo systemctl start --no-block "$unit"
printf 'queued %s\n' "$unit"
printf 'check detached result with: host-result %s --wait 900\n' "$unit"
