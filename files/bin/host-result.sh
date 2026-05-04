#!/usr/bin/env bash
# host-result <unit> [--wait seconds] [--tail 40]
# Wait for a named host job unit and print its recent journal.
set -euo pipefail

unit=""
wait_seconds=0
tail_lines=40

while [ "$#" -gt 0 ]; do
	case "$1" in
	--wait)
		wait_seconds="$2"
		shift 2
		;;
	--tail)
		tail_lines="$2"
		shift 2
		;;
	-h | --help)
		echo "usage: host-result <unit> [--wait seconds] [--tail 40]"
		exit 0
		;;
	*)
		if [ -z "$unit" ]; then
			unit="$1"
		else
			echo "unexpected arg: $1" >&2
			exit 64
		fi
		shift
		;;
	esac
done

if [ -z "$unit" ]; then
	echo "usage: host-result <unit> [--wait seconds] [--tail 40]" >&2
	exit 64
fi

case "$unit" in
*.service) ;;
*) unit="$unit.service" ;;
esac

start_ts=$(date +%s)
while :; do
	active_state="$(systemctl show -P ActiveState "$unit")"
	result="$(systemctl show -P Result "$unit")"

	if [ "$active_state" != "activating" ] && [ "$active_state" != "active" ]; then
		break
	fi

	now=$(date +%s)
	if [ "$wait_seconds" -le 0 ] || [ $((now - start_ts)) -ge "$wait_seconds" ]; then
		echo "[host-result] $unit still $active_state result=$result" >&2
		exit 2
	fi
	sleep 2
done

exec_status="$(systemctl show -P ExecMainStatus "$unit")"
echo "[host-result] unit $unit active=$active_state result=$result exit=${exec_status:-?}"
journalctl --no-pager -n "$tail_lines" -u "$unit" || true

if [ "$result" = "success" ]; then
	exit 0
fi
exit 1
