#!/usr/bin/env bash
set -euo pipefail
export HERMES_HOME="@hermesHome@"
export PYTHONPATH="@hermesOverrides@"${PYTHONPATH:+:$PYTHONPATH}
exec "@hermesVenv@/bin/hermes" "$@"
