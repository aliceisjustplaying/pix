#!@shell@
# shellcheck shell=bash
# Not directly runnable: the tokens below are filled in at install time by
# `substitute --subst-var-by ...` in pkgs/portless/default.nix.
export PATH="@runtimePath@:$PATH"

if [ -z "${PORTLESS_LAN_IP:-}" ]; then
	portless_tailscale_ip="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
	if [ -n "$portless_tailscale_ip" ]; then
		export PORTLESS_LAN_IP="$portless_tailscale_ip"
	fi
fi

if [ -n "${PORTLESS_LAN_IP:-}" ]; then
	export PORTLESS_LAN="${PORTLESS_LAN:-1}"
	export PORTLESS_TLD="${PORTLESS_TLD:-local}"
	export PORTLESS_HTTPS="${PORTLESS_HTTPS:-0}"
fi

if [ -n "${PORTLESS_LAN_IP:-}" ] && [ -z "${PORTLESS_BIND_HOST:-}" ]; then
	export PORTLESS_BIND_HOST="$PORTLESS_LAN_IP"
fi

exec @node@ @libexec@/dist/cli.js "$@"
