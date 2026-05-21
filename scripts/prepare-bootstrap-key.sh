#!/usr/bin/env bash
set -euo pipefail

HOST_KEY_PATH="${1:-secrets/age/pix2-host.key}"
EXTRA_FILES_DIR="${2:-.nixos-anywhere-extra}"

mkdir -p "$(dirname "$HOST_KEY_PATH")"
mkdir -p "$EXTRA_FILES_DIR/var/lib/sops-nix"

if [[ ! -f "$HOST_KEY_PATH" ]]; then
	age-keygen -o "$HOST_KEY_PATH"
fi

install -m 0400 "$HOST_KEY_PATH" "$EXTRA_FILES_DIR/var/lib/sops-nix/key.txt"

echo "Host age public recipient:"
age-keygen -y "$HOST_KEY_PATH"
echo
echo "Bootstrap files prepared in: $EXTRA_FILES_DIR"
