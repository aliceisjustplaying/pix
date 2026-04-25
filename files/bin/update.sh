#!/usr/bin/env bash
set -euo pipefail
quoted_args=()
for arg in "$@"; do
  quoted_args+=("$(printf '%q' "$arg")")
done
args_string="${quoted_args[*]}"
cd @workspaceSrc@/piclaw-customizations
git pull
exec @home@/.local/bin/host-queue \
  piclaw-update \
  "export PATH=@home@/.local/bin:@home@/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin:\$PATH && cd @workspaceSrc@/piclaw-customizations && sudo ./scripts/piclaw-update-host.sh${args_string:+ ${args_string}}"
