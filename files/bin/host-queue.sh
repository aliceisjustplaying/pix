#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $(basename "$0") <job-name> <command>" >&2
  exit 64
fi

job_name="$1"
shift
command_string="$1"
command_b64="$(printf '%s' "$command_string" | base64 -w0)"

exec ssh -o BatchMode=yes localhost /run/current-system/sw/bin/bash -s -- "$job_name" "$command_b64" <<'EOF'
set -euo pipefail
export PATH=@home@/.local/bin:@home@/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin:$PATH

job_name="$1"
command_b64="$2"
command_string="$(printf '%s' "$command_b64" | base64 -d)"
unit_name="${job_name}-$(date +%s)"

watcher_script='set -euo pipefail
unit="$1"
status_dir="/workspace/.piclaw/host-queue-results"
mkdir -p "$status_dir"
start_ts=$(date +%s)
result="running"
exit_code=124
while :; do
  now=$(date +%s)
  elapsed=$((now - start_ts))
  journal="$(journalctl --no-pager -n 200 -u "$unit" -o cat 2>/dev/null || true)"
  if printf "%s\n" "$journal" | grep -qE "Failed with result|Main process exited, code=(exited|killed), status=[1-9]"; then
    result="failed"
    exit_code=1
    break
  fi
  if printf "%s\n" "$journal" | grep -qE "Deactivated successfully"; then
    result="success"
    exit_code=0
    break
  fi
  if [ "$elapsed" -ge 900 ]; then
    result="timeout"
    exit_code=124
    break
  fi
  sleep 3
done
completed_at=$(date -Is)
journalctl --no-pager -n 120 -u "$unit" >"$status_dir/$unit.journal" 2>&1 || true
{
  printf "unit=%q\n" "$unit"
  printf "result=%q\n" "$result"
  printf "exit_code=%q\n" "$exit_code"
  printf "elapsed_seconds=%q\n" "$elapsed"
  printf "completed_at=%q\n" "$completed_at"
  printf "journal=%q\n" "$status_dir/$unit.journal"
} >"$status_dir/$unit.status.tmp"
mv "$status_dir/$unit.status.tmp" "$status_dir/$unit.status"
exit 0
'
watcher_b64="$(printf '%s' "$watcher_script" | base64 -w0)"
sudo systemd-run \
  --quiet \
  --collect \
  --service-type=exec \
  --uid=agent \
  --gid=users \
  --setenv=HOME=@home@ \
  --setenv=USER=agent \
  --setenv=PATH=@home@/.local/bin:@home@/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin \
  --unit "${unit_name}-watch" \
  --description "$job_name result watcher" \
  /run/current-system/sw/bin/bash -lc 'printf "%s" "$1" | base64 -d | bash -s -- "$2"' bash "$watcher_b64" "$unit_name"

printf 'queued %s\n' "$unit_name"
printf 'check detached result with: host-result %s --wait 900\n' "$unit_name"

sudo systemd-run \
  --quiet \
  --collect \
  --service-type=exec \
  --uid=agent \
  --gid=users \
  --setenv=HOME=@home@ \
  --setenv=USER=agent \
  --setenv=PATH=@home@/.local/bin:@home@/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin \
  --unit "$unit_name" \
  --description "$job_name" \
  /run/current-system/sw/bin/bash -lc "$command_string"
EOF
