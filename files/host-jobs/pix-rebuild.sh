#!/usr/bin/env bash
set -euo pipefail
cd @workspaceSrc@/pix
runuser -u agent -- env HOME=@agentHome@ git pull --ff-only
nixos-rebuild switch --flake path:@agentHome@/workspace/src/pix#@flakeAttr@
