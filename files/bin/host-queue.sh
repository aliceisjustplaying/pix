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

printf 'queued %s\n' "$unit_name"
printf 'follow logs with: ssh localhost sudo journalctl -u %s -f\n' "$unit_name"
EOF
