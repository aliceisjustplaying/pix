#!/usr/bin/env bash
set -euo pipefail

unit=hermes-gateway.service
systemctl is-active --quiet "$unit"

main_pid="$(systemctl show "$unit" -p MainPID --value)"
if [ -z "$main_pid" ] || [ "$main_pid" = "0" ]; then
	echo "no MainPID for $unit" >&2
	exit 1
fi

pid_json="$(cat /workspace/.hermes/gateway.pid)"
pid_file_pid="$(printf '%s\n' "$pid_json" | jq -r '.pid')"
if [ "$pid_file_pid" != "$main_pid" ]; then
	echo "gateway.pid has $pid_file_pid, systemd has $main_pid" >&2
	exit 1
fi

if ! ss -ltnp | grep -F "127.0.0.1:8084" | grep -F "pid=$main_pid," >/dev/null; then
	echo "127.0.0.1:8084 is not owned by PID $main_pid" >&2
	exit 1
fi

HERMES_HOME=/workspace/.hermes \
PYTHONPATH=/workspace/.hermes/overrides \
/workspace/.hermes/venv/bin/hermes --version >/dev/null

echo "hermes gateway ok: pid $main_pid owns 127.0.0.1:8084"
