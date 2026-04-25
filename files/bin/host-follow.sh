#!/usr/bin/env bash
# host-follow <unit> [--heartbeat 45] [--max 900] [--tail 40]
#
# Poll a transient systemd unit on the host until it reaches a terminal
# state, printing a heartbeat on the configured cadence and exiting
# with the unit's real result code. Use this instead of `journalctl -f`
# so the agent doesn't sit silently in a follower stream.
#
# Implementation note: host-queue starts units with `systemd-run --collect`,
# which causes systemd to forget the unit's `Result` once it exits.
# Polling `systemctl show` therefore returns `Result=success` even for
# failed runs once they're complete. We instead grep the journal for the
# systemd-emitted terminal lines (`Deactivated successfully` /
# `Failed with result`), which are stable and reliable.
set -euo pipefail

unit=""
heartbeat=45
max_seconds=900
tail_lines=40

while [ "$#" -gt 0 ]; do
  case "$1" in
    --heartbeat) heartbeat="$2"; shift 2 ;;
    --max) max_seconds="$2"; shift 2 ;;
    --tail) tail_lines="$2"; shift 2 ;;
    -h|--help)
      echo "usage: host-follow <unit> [--heartbeat 45] [--max 900] [--tail 40]"
      exit 0
      ;;
    *)
      if [ -z "$unit" ]; then unit="$1"; else
        echo "unexpected arg: $1" >&2; exit 64
      fi
      shift ;;
  esac
done

if [ -z "$unit" ]; then
  echo "usage: host-follow <unit> [--heartbeat 45] [--max 900] [--tail 40]" >&2
  exit 64
fi

start_ts=$(date +%s)
last_beat=$start_ts

echo "[host-follow] watching $unit (heartbeat=$heartbeat s, max=$max_seconds s)"

# Read the unit's recent journal in one shot. Grep for the systemd-
# emitted terminal lines because `--collect`'d transient units lose
# their Result property after exit.
check_terminal() {
  local journal
  journal="$(ssh -o BatchMode=yes localhost \
    "journalctl --no-pager -n 200 -u $unit -o cat 2>/dev/null" || true)"

  if printf '%s\n' "$journal" | grep -qE 'Failed with result|Main process exited, code=(exited|killed), status=[1-9]'; then
    echo "failed"
    return 0
  fi
  if printf '%s\n' "$journal" | grep -qE 'Deactivated successfully'; then
    echo "success"
    return 0
  fi
  echo "running"
}

while :; do
  now=$(date +%s)
  elapsed=$(( now - start_ts ))

  if [ "$elapsed" -ge "$max_seconds" ]; then
    echo "[host-follow] TIMEOUT after $elapsed s; unit $unit still not terminal"
    ssh -o BatchMode=yes localhost "journalctl --no-pager -n $tail_lines -u $unit" || true
    exit 124
  fi

  terminal="$(check_terminal)"
  case "$terminal" in
    success)
      echo "[host-follow] unit $unit succeeded after $elapsed s"
      ssh -o BatchMode=yes localhost "journalctl --no-pager -n $tail_lines -u $unit" || true
      exit 0
      ;;
    failed)
      echo "[host-follow] unit $unit FAILED after $elapsed s"
      ssh -o BatchMode=yes localhost "journalctl --no-pager -n $tail_lines -u $unit" || true
      exit 1
      ;;
  esac

  if [ $(( now - last_beat )) -ge "$heartbeat" ]; then
    last_beat=$now
    echo "[host-follow] still running after $elapsed s"
  fi

  sleep 3
done
