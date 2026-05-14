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
dependency_min_age_hours() { printf '%s' "${PIX_DEPENDENCY_MIN_AGE_HOURS:-24}"; }
allow_fresh_dependencies() { [[ -n ${PIX_ALLOW_FRESH_DEPS:-} ]]; }

freshness_exempt() {
	local part lower
	for part in "$@"; do
		lower=${part,,}
		[[ $lower =~ ^(@[^/]+/)?(claude|codex) ]] && return 0
	done
	return 1
}

cutoff_epoch() {
	python3 -c 'import time, sys; print(time.time() - float(sys.argv[1]) * 3600)' "$(dependency_min_age_hours)"
}

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

# Latest allowed version of an npm package via registry metadata.
npm_latest_version() {
	local pkg=$1 metadata cutoff version
	metadata=$(curl -fsSL "https://registry.npmjs.org/$pkg")
	if freshness_exempt "$pkg" || allow_fresh_dependencies; then
		printf '%s\n' "$metadata" | jq -r '."dist-tags".latest'
		return
	fi
	cutoff=$(cutoff_epoch)
	version=$(printf '%s\n' "$metadata" | jq -r --argjson cutoff "$cutoff" '
		. as $root
		| .time
		| to_entries
		| map(select(.key != "created" and .key != "modified"))
		| map(select($root.versions[.key] != null))
		| map(. + {ts: (.value | sub("\\.[0-9]+"; "") | fromdateiso8601)})
		| map(select(.ts <= $cutoff))
		| max_by(.ts).key // empty
	')
	[[ -n $version && $version != null ]] || die "$pkg: no release older than $(dependency_min_age_hours)h"
	printf '%s\n' "$version"
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
regen_lockfile() (
	local npm_pkg=$1 version=$2 dest=$3 url tmp
	url=$(npm_tarball_url "$npm_pkg" "$version")
	tmp=$(mktemp -d)
	trap 'rm -rf "$tmp"' EXIT
	curl -fsSL "$url" -o "$tmp/pkg.tgz"
	tar -xzf "$tmp/pkg.tgz" -C "$tmp"
	(
		cd "$tmp/package"
		npm install --min-release-age=0 --package-lock-only --ignore-scripts --no-audit --no-fund --silent
	)
	cp "$tmp/package/package-lock.json" "$repo/$dest"
)

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
	local attr=$1 nix_file=$2 owner=$3 repo=$4 cur new releases cutoff
	cur=$(nix_field "$nix_file" version)
	if freshness_exempt "$attr" "$owner" "$repo" || allow_fresh_dependencies; then
		new=$(curl -fsSL -H 'Accept: application/vnd.github+json' \
			"https://api.github.com/repos/${owner}/${repo}/releases/latest" |
			jq -r .tag_name | sed -E 's/^v//')
	else
		releases=$(curl -fsSL -H 'Accept: application/vnd.github+json' \
			"https://api.github.com/repos/${owner}/${repo}/releases?per_page=100")
		cutoff=$(cutoff_epoch)
		new=$(printf '%s\n' "$releases" | jq -r --argjson cutoff "$cutoff" '
			map(select(.draft | not))
			| map(select(.prerelease | not))
			| map(select(.published_at != null))
			| map(. + {ts: (.published_at | fromdateiso8601)})
			| map(select(.ts <= $cutoff))
			| max_by(.ts).tag_name // empty
		' | sed -E 's/^v//')
	fi
	[[ -n $new && $new != null ]] || die "$attr: couldn't read latest GitHub release"
	replace_field "$nix_file" version "$new"
	fix_build_hash "$attr" "$nix_file" hash
	fix_build_hash "$attr" "$nix_file" vendorHash
	log "$attr: $cur -> $new"
}

restore_fresh_flake_inputs() {
	local before=$1 current=flake.lock min_age
	min_age=$(dependency_min_age_hours)
	python3 - "$before" "$current" "$min_age" <<'PY'
import json
import re
import sys
import time

before_path, current_path, min_age = sys.argv[1], sys.argv[2], float(sys.argv[3])
exempt_re = re.compile(r"^(@[^/]+/)?(claude|codex)", re.IGNORECASE)
cutoff = time.time() - min_age * 3600

with open(before_path, encoding="utf-8") as f:
    before = json.load(f)
with open(current_path, encoding="utf-8") as f:
    current = json.load(f)

restored = []
before_nodes = before.get("nodes", {})
for name, node in list(current.get("nodes", {}).items()):
    locked = node.get("locked", {})
    last_modified = locked.get("lastModified")
    if not isinstance(last_modified, int):
        continue
    parts = [name, locked.get("owner"), locked.get("repo")]
    if any(exempt_re.search(str(part or "")) for part in parts):
        continue
    if last_modified > cutoff and name in before_nodes:
        if before_nodes[name].get("locked", {}).get("lastModified") != last_modified:
            current["nodes"][name] = before_nodes[name]
            restored.append(name)

if restored:
    with open(current_path, "w", encoding="utf-8") as f:
        json.dump(current, f, indent=2)
        f.write("\n")
    print("==> kept fresh flake inputs at previous lock: " + ", ".join(restored))
PY
}

main() {
	need curl
	need jq
	need tar
	need npm
	need sed
	need git
	need python3
	need nix-prefetch-url

	local flake_before
	flake_before=$(mktemp)
	trap 'rm -f "${flake_before:-}"' EXIT
	if git show HEAD:flake.lock >"$flake_before" 2>/dev/null; then
		:
	else
		cp flake.lock "$flake_before"
	fi

	log "updating flake inputs"
	nix "${NIX_FLAGS[@]}" flake update
	restore_fresh_flake_inputs "$flake_before"

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
