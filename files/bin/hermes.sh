#!/usr/bin/env bash
set -euo pipefail
export HERMES_HOME=/workspace/.hermes
export PYTHONPATH=/workspace/.hermes/overrides${PYTHONPATH:+:$PYTHONPATH}
export LD_LIBRARY_PATH=@hermesLibraryPath@${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
exec /workspace/.hermes/venv/bin/hermes "$@"
