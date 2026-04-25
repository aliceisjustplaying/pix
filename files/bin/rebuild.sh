#!/usr/bin/env bash
set -euo pipefail
cd @workspaceSrc@/pix
git pull
exec @home@/.local/bin/host-queue \
  pix-rebuild \
  "export PATH=@home@/.local/bin:@home@/.bun/bin:/etc/profiles/per-user/agent/bin:/usr/local/bin:/run/wrappers/bin:/run/current-system/sw/bin:\$PATH && cd @workspaceSrc@/pix && sudo nixos-rebuild switch --flake path:@home@/workspace/src/pix#pix"
