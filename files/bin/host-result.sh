#!/usr/bin/env bash
# host-result <unit> [--wait seconds] [--tail 40]
# Read the detached host-queue result written by host-queue's host-side watcher.
set -euo pipefail

unit=""
wait_seconds=0
tail_lines=40
status_dir="/workspace/.piclaw/host-queue-results"

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
    -h|--help)
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

status_file="$status_dir/$unit.status"
start_ts=$(date +%s)
while [ ! -f "$status_file" ]; do
  now=$(date +%s)
  if [ "$wait_seconds" -le 0 ] || [ $((now - start_ts)) -ge "$wait_seconds" ]; then
    echo "[host-result] no detached result yet for $unit" >&2
    exit 2
  fi
  sleep 2
done

# shellcheck disable=SC1090
source "$status_file"
result="${result:-unknown}"
exit_code="${exit_code:-2}"
elapsed_seconds="${elapsed_seconds:-?}"
completed_at="${completed_at:-?}"
journal="${journal:-$status_dir/$unit.journal}"

echo "[host-result] unit $unit result=$result exit=$exit_code elapsed=${elapsed_seconds}s completed=$completed_at"
if [ -f "$journal" ]; then
  tail -n "$tail_lines" "$journal"
fi
exit "$exit_code"
