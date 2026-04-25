#!/usr/bin/env bash
set -euo pipefail
cd @workspaceSrc@/piclaw-customizations
exec ./scripts/piclaw-verify-deploy.sh "$@"
