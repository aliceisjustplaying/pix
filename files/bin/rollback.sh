#!/usr/bin/env bash
set -euo pipefail
case "$*" in
"")
	unit="piclaw-rollback.service"
	;;
"--force")
	unit="piclaw-rollback-force.service"
	;;
*)
	echo "usage: rollback [--force]" >&2
	exit 64
	;;
esac
sudo systemctl start --no-block "$unit"
printf 'queued %s\n' "$unit"
printf 'check detached result with: host-result %s --wait 900\n' "$unit"
