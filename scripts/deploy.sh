#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "usage: $0 <server-ip>" >&2
	exit 1
fi

SERVER_IP="$1"
KEXEC_URL="${KEXEC_URL:-https://github.com/nix-community/nixos-images/releases/download/nixos-25.11/nixos-kexec-installer-noninteractive-aarch64-linux.tar.gz}"

nix run github:nix-community/nixos-anywhere -- \
	--flake .#pix \
	--build-on remote \
	--extra-files ./.nixos-anywhere-extra \
	--kexec "$KEXEC_URL" \
	root@"$SERVER_IP"
