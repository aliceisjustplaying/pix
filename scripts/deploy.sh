#!/usr/bin/env bash
set -euo pipefail

usage() {
	cat >&2 <<'USAGE'
usage: scripts/deploy.sh [--host pix|pix2] <server-ip>

The one-argument form deploys the current ARM host: scripts/deploy.sh <server-ip>
USAGE
}

host="pix"

while [[ $# -gt 0 ]]; do
	case "$1" in
	--host)
		if [[ $# -lt 2 ]]; then
			usage
			exit 64
		fi
		host="${2:-}"
		shift 2
		;;
	-h | --help)
		usage
		exit 0
		;;
	-*)
		usage
		exit 64
		;;
	*)
		break
		;;
	esac
done

if [[ $# -ne 1 || -z "$host" ]]; then
	usage
	exit 64
fi

server_ip="$1"

case "$host" in
pix)
	kexec_arch="aarch64"
	;;
pix2)
	kexec_arch="x86_64"
	;;
*)
	echo "unknown host: $host" >&2
	exit 64
	;;
esac

kexec_url="${KEXEC_URL:-https://github.com/nix-community/nixos-images/releases/download/nixos-25.11/nixos-kexec-installer-noninteractive-${kexec_arch}-linux.tar.gz}"

nix run github:nix-community/nixos-anywhere -- \
	--flake ".#${host}" \
	--build-on remote \
	--extra-files ./.nixos-anywhere-extra \
	--kexec "$kexec_url" \
	root@"$server_ip"
