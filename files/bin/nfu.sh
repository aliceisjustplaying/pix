#!/usr/bin/env bash
# nfu: bump every pinned input in /workspace/src/pix.
#
# Updates:
#   - all flake inputs (`nix flake update`)
#   - every first-party package under pkgs/ that tracks an upstream version
#       * amp-code        (npm: @sourcegraph/amp,                   sha512)
#       * claude-code-acp (npm: @zed-industries/claude-code-acp,    sha256, +lockfile)
#       * cli-proxy-api   (github: router-for-me/CLIProxyAPI,       Go vendorHash)
#       * codex-acp       (npm: @agentclientprotocol/codex-acp,     sha512, +lockfile)
#       * droid           (npm: @factory/cli-linux-{arm64,x64},     sha512)
#       * portless        (npm: portless,                           sha256)
#
# Excluded on purpose:
#   - tsshd is firewall-pinned (UDP 61001-61999) and lives inside overrideAttrs;
#     bump it manually.
#
# Validates the result with `nix build` of every package before exiting.
# npm, Bun, and uv have native resolver age gates in user config. This script
# still refuses Nix/GitHub pins newer than 24 hours unless explicitly
# bypassed with PIX_ALLOW_FRESH_DEPS=1 and PIX_FRESH_DEPS_REASON=...
# Pair with `rebuild` (or use the `nfur` alias) to actually deploy.

set -euo pipefail

repo="/workspace/src/pix"
cd "$repo"

NIX_FLAGS=(--extra-experimental-features "nix-command flakes")
PLACEHOLDER_HASH='sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA='

log() { printf '==> %s\n' "$*"; }
die() {
	printf 'nfu: %s\n' "$*" >&2
	exit 1
}
need() { command -v "$1" >/dev/null 2>&1 || die "missing tool: $1"; }

# Read a `<field> = "<value>";` assignment from a .nix file.
nix_field() {
	local file=$1 field=$2 val
	val=$(sed -n -E "s/^[[:space:]]*${field} = \"([^\"]+)\";.*/\1/p" "$file" | head -n1)
	[[ -n $val ]] || die "$file: couldn't read field '$field'"
	printf '%s' "$val"
}

# Replace the single `<field> = "...";` assignment in a .nix file.
# Fails fast when the match count isn't exactly 1.
replace_field() {
	local file=$1 field=$2 new=$3 count rc
	[[ -f $file ]] || die "$file: no such file"
	# grep -c returns 0 with matches, 1 with none, 2+ on real error. We tolerate
	# 0 and 1 here (the count==1 check below is what enforces correctness) but
	# fail loud on rc>=2 so a busted regex or unreadable file doesn't silently
	# become "0 matches".
	count=$(grep -c -E "^[[:space:]]*${field} = \"[^\"]+\";" "$file") && rc=0 || rc=$?
	[[ $rc -le 1 ]] || die "$file: grep failed (rc=$rc) reading field '${field}'"
	[[ $count -eq 1 ]] || die "$file: expected exactly one '${field}' line, got $count"
	sed -i -E "s|^([[:space:]]*)${field} = \"[^\"]+\";|\\1${field} = \"${new}\";|" "$file"
}

# SRI hash of an HTTP URL with explicit algo (sha256 | sha512).
sri_for_url() {
	local url=$1 algo=$2 base32
	base32=$(nix-prefetch-url --type "$algo" "$url")
	nix "${NIX_FLAGS[@]}" hash convert --hash-algo "$algo" --to sri "$base32"
}

# Latest version of an npm package via the registry's /<pkg>/latest endpoint.
npm_latest_version() {
	curl -fsSL "https://registry.npmjs.org/$1/latest" | jq -r .version
}

# Build the canonical tarball URL for an npm package.
#   @scope/name -> https://registry.npmjs.org/@scope/name/-/name-<v>.tgz
#   name        -> https://registry.npmjs.org/name/-/name-<v>.tgz
npm_tarball_url() {
	local pkg=$1 version=$2 basename=${1##*/}
	printf 'https://registry.npmjs.org/%s/-/%s-%s.tgz' "$pkg" "$basename" "$version"
}

# Bump version + source hash on a .nix file that fetches an npm tarball.
update_npm() {
	local nix_file=$1 npm_pkg=$2 algo=$3 cur new url sri
	cur=$(nix_field "$nix_file" version)
	new=$(npm_latest_version "$npm_pkg")
	url=$(npm_tarball_url "$npm_pkg" "$new")
	sri=$(sri_for_url "$url" "$algo")
	replace_field "$nix_file" version "$new"
	replace_field "$nix_file" hash "$sri"
	log "$(basename "$nix_file" .nix): $cur -> $new"
}

update_droid() {
	local nix_file=pkgs/droid.nix cur new arm64_url x64_url arm64_sri x64_sri
	cur=$(nix_field "$nix_file" version)
	new=$(npm_latest_version '@factory/cli-linux-arm64')
	arm64_url=$(npm_tarball_url '@factory/cli-linux-arm64' "$new")
	x64_url=$(npm_tarball_url '@factory/cli-linux-x64' "$new")
	arm64_sri=$(sri_for_url "$arm64_url" sha512)
	x64_sri=$(sri_for_url "$x64_url" sha512)
	replace_field "$nix_file" version "$new"
	replace_field "$nix_file" droidArm64Hash "$arm64_sri"
	replace_field "$nix_file" droidX64Hash "$x64_sri"
	log "droid: $cur -> $new"
}

# Refresh `npmDepsHash` by building with a known-bad placeholder and scraping
# the "got:" hash mismatch line. Re-runnable.
fix_build_hash() {
	local attr=$1 nix_file=$2 field=$3 out got
	replace_field "$nix_file" "$field" "$PLACEHOLDER_HASH"
	out=$(nix "${NIX_FLAGS[@]}" build ".#${attr}" --no-link 2>&1 || true)
	got=$(printf '%s\n' "$out" | sed -n -E 's/.*got:[[:space:]]+(sha[0-9]+-[A-Za-z0-9+/=]+).*/\1/p' | head -n1)
	if [[ -z $got ]]; then
		printf '%s\n' "$out" >&2
		die "$attr: couldn't determine '$field'"
	fi
	replace_field "$nix_file" "$field" "$got"
}

# Regenerate a bundled package-lock.json by extracting the upstream tarball
# and running `npm install --package-lock-only` against the published package.json.
regen_lockfile() {
	local npm_pkg=$1 version=$2 dest=$3 url tmp
	url=$(npm_tarball_url "$npm_pkg" "$version")
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' RETURN
	curl -fsSL "$url" -o "$tmp/pkg.tgz"
	tar -xzf "$tmp/pkg.tgz" -C "$tmp"
	(
		cd "$tmp/package"
		npm install --min-release-age=0 --package-lock-only --ignore-scripts --no-audit --no-fund --silent
	)
	cp "$tmp/package/package-lock.json" "$repo/$dest"
}

# npm package with an externally bundled package-lock.json (buildNpmPackage
# postPatch trick): bump version + tarball hash, regen the lockfile, then
# refresh npmDepsHash via build-and-fix.
update_npm_with_lockfile() {
	local attr=$1 nix_file=$2 npm_pkg=$3 algo=$4 lockfile=$5 version
	update_npm "$nix_file" "$npm_pkg" "$algo"
	version=$(nix_field "$nix_file" version)
	regen_lockfile "$npm_pkg" "$version" "$lockfile"
	fix_build_hash "$attr" "$nix_file" npmDepsHash
}

# fetchFromGitHub + buildGoModule: bump version, then build-and-fix both
# the source `hash` and `vendorHash` from nix's mismatch output.
update_go_github() {
	local attr=$1 nix_file=$2 owner=$3 repo=$4 cur new
	cur=$(nix_field "$nix_file" version)
	new=$(curl -fsSL -H 'Accept: application/vnd.github+json' \
		"https://api.github.com/repos/${owner}/${repo}/releases/latest" |
		jq -r .tag_name | sed -E 's/^v//')
	[[ -n $new && $new != null ]] || die "$attr: couldn't read latest GitHub release"
	replace_field "$nix_file" version "$new"
	fix_build_hash "$attr" "$nix_file" hash
	fix_build_hash "$attr" "$nix_file" vendorHash
	log "$attr: $cur -> $new"
}

main() {
	need curl
	need jq
	need tar
	need npm
	need sed
	need nix-prefetch-url

	log "updating flake inputs"
	nix "${NIX_FLAGS[@]}" flake update

	log "amp-code"
	update_npm pkgs/amp.nix '@sourcegraph/amp' sha512

	log "droid"
	update_droid

	log "portless"
	update_npm pkgs/portless/default.nix portless sha256

	log "claude-code-acp"
	update_npm_with_lockfile claude-code-acp \
		pkgs/claude-code-acp/default.nix \
		'@zed-industries/claude-code-acp' sha256 \
		pkgs/claude-code-acp/package-lock.json

	log "codex-acp"
	update_npm_with_lockfile codex-acp \
		pkgs/codex-acp.nix \
		'@agentclientprotocol/codex-acp' sha512 \
		pkgs/codex-acp-package-lock.json

	log "cli-proxy-api"
	update_go_github cli-proxy-api pkgs/cli-proxy-api.nix router-for-me CLIProxyAPI

	log "checking dependency freshness"
	./scripts/check-dependency-freshness.py

	log "validating builds"
	nix "${NIX_FLAGS[@]}" build \
		.#amp-code \
		.#claude-code-acp \
		.#cli-proxy-api \
		.#codex-acp \
		.#droid \
		.#portless \
		--no-link

	log "done"
}

main "$@"
