#!/usr/bin/env bash
set -euo pipefail

repo="/workspace/src/pix"
cd "$repo"

python3 <<'PY'
import json
import re
import subprocess
import urllib.request
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


def sri_for_url(url):
    base32 = run(["nix-prefetch-url", "--type", "sha256", url])
    return run(["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", base32])


def replace(path, pattern, repl):
    file = repo / path
    text = file.read_text()
    new_text, count = re.subn(pattern, repl, text, flags=re.S)
    if count != 1:
        raise RuntimeError(f"{path}: expected one replacement for {pattern!r}, got {count}")
    file.write_text(new_text)


print("updating nixpkgs-unstable")
subprocess.run([
    "nix", "flake", "update", "nixpkgs-unstable",
    "--extra-experimental-features", "nix-command flakes",
], check=True)

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
PY
