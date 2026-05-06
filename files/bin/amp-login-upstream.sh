#!/usr/bin/env bash
set -euo pipefail

settings_file="$(mktemp --tmpdir amp-upstream-settings.XXXXXX.json)"
trap 'rm -f "$settings_file"' EXIT
printf '{}\n' > "$settings_file"

AMP_SETTINGS_FILE="$settings_file" AMP_URL=https://ampcode.com amp login
