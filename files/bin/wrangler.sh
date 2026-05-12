#!/usr/bin/env bash
set -euo pipefail
exec npm exec --yes wrangler@4.85.0 -- "$@"
