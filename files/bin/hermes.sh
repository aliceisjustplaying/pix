#!/usr/bin/env bash
set -euo pipefail
export HERMES_HOME=/workspace/.hermes
export PYTHONPATH=/workspace/.hermes/overrides${PYTHONPATH:+:$PYTHONPATH}
exec /workspace/.hermes/venv/bin/hermes "$@"
