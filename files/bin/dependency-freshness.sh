#!/usr/bin/env bash
set -euo pipefail
cd /workspace/src/pix
exec ./scripts/check-dependency-freshness.py "$@"
