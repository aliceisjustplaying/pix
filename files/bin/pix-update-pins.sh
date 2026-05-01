#!/usr/bin/env bash
set -euo pipefail

repo="/workspace/src/pix"
cd "$repo"

python3 <<'PY'
import json
import re
import subprocess
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

repo = Path("/workspace/src/pix")


def run(args, **kwargs):
    return subprocess.run(args, text=True, check=True, capture_output=True, **kwargs).stdout.strip()


def github_json(url):
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "pix-update-pins",
    })
    with urllib.request.urlopen(req) as response:
        return json.load(response)


def sri_for_url(url, unpack=False):
    args = ["nix-prefetch-url", "--type", "sha256"]
    if unpack:
        args.append("--unpack")
    args.append(url)
    base32 = run(args)
    return run(["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", base32])


def replace(path, pattern, repl):
    file = repo / path
    text = file.read_text()
    new_text, count = re.subn(pattern, repl, text, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{path}: expected one replacement for {pattern!r}, got {count}")
    file.write_text(new_text)


def set_vibes_vendor_hash(hash_value):
    replace(
        "pkgs/vibes.nix",
        r'vendorHash = "sha256-[^"]+";',
        f'vendorHash = "{hash_value}";',
    )


def update_bun_hashes(hash_value):
    file = repo / "flake.nix"
    text = file.read_text()
    pattern = r'(bun = unstablePkgs\.bun\.overrideAttrs .*?\n\s+}\);\n)'
    match = re.search(pattern, text, flags=re.S)
    if not match:
        raise RuntimeError("flake.nix: could not find Bun override block")
    block = match.group(1)
    new_block, count = re.subn(r'hash = "sha256-[^"]+";', f'hash = "{hash_value}";', block)
    if count != 2:
        raise RuntimeError(f"flake.nix: expected two Bun hash replacements, got {count}")
    file.write_text(text[:match.start(1)] + new_block + text[match.end(1):])


print("updating nixpkgs-unstable")
subprocess.run([
    "nix", "flake", "update", "nixpkgs-unstable",
    "--extra-experimental-features", "nix-command flakes",
], check=True)

bun = github_json("https://api.github.com/repos/oven-sh/bun/releases/latest")
bun_tag = bun["tag_name"]
bun_version = bun_tag.removeprefix("bun-v")
bun_url = f"https://github.com/oven-sh/bun/releases/download/{bun_tag}/bun-linux-aarch64.zip"
bun_hash = sri_for_url(bun_url)
replace(
    "flake.nix",
    r'(bun = unstablePkgs\.bun\.overrideAttrs.*?version = ")[^"]+(";)',
    rf'\g<1>{bun_version}\2',
)
update_bun_hashes(bun_hash)
print(f"bun {bun_version}")

codex = github_json("https://api.github.com/repos/zed-industries/codex-acp/releases/latest")
codex_version = codex["tag_name"].removeprefix("v")
codex_url = f"https://github.com/zed-industries/codex-acp/releases/download/v{codex_version}/codex-acp-{codex_version}-aarch64-unknown-linux-gnu.tar.gz"
codex_hash = sri_for_url(codex_url)
replace("pkgs/codex-acp.nix", r'version = "[^"]+";', f'version = "{codex_version}";')
replace("pkgs/codex-acp.nix", r'hash = "sha256-[^"]+";', f'hash = "{codex_hash}";')
print(f"codex-acp {codex_version}")

with urllib.request.urlopen("https://registry.npmjs.org/portless/latest") as response:
    portless = json.load(response)
portless_version = portless["version"]
portless_url = f"https://registry.npmjs.org/portless/-/portless-{portless_version}.tgz"
portless_hash = sri_for_url(portless_url)
replace("pkgs/portless.nix", r'version = "[^"]+";', f'version = "{portless_version}";')
replace("pkgs/portless.nix", r'hash = "sha256-[^"]+";', f'hash = "{portless_hash}";')
print(f"portless {portless_version}")

vibes_repo = github_json("https://api.github.com/repos/rcarmo/vibes")
vibes_branch = vibes_repo["default_branch"]
vibes_ref = github_json(f"https://api.github.com/repos/rcarmo/vibes/branches/{vibes_branch}")
vibes_rev = vibes_ref["commit"]["sha"]
vibes_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
vibes_url = f"https://github.com/rcarmo/vibes/archive/{vibes_rev}.tar.gz"
vibes_hash = sri_for_url(vibes_url, unpack=True)
replace("pkgs/vibes.nix", r'version = "0\.0\.0-unstable-[^"]+";', f'version = "0.0.0-unstable-{vibes_date}";')
replace("pkgs/vibes.nix", r'rev = "[^"]+";', f'rev = "{vibes_rev}";')
replace("pkgs/vibes.nix", r'hash = "sha256-[^"]+";', f'hash = "{vibes_hash}";')

original_vibes = (repo / "pkgs/vibes.nix").read_text()
set_vibes_vendor_hash("sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
build = subprocess.run(
    ["nix", "build", ".#vibes", "--no-link", "--extra-experimental-features", "nix-command flakes"],
    cwd=repo,
    text=True,
    capture_output=True,
)
output = build.stdout + build.stderr
match = re.search(r"got:\s+(sha256-[A-Za-z0-9+/=]+)", output)
if not match:
    (repo / "pkgs/vibes.nix").write_text(original_vibes)
    sys.stderr.write(output)
    raise RuntimeError("could not determine vibes vendorHash")
set_vibes_vendor_hash(match.group(1))
print(f"vibes {vibes_rev[:12]}")
PY
