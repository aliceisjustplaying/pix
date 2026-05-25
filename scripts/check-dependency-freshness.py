#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.parse
import urllib.request
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_MIN_AGE_HOURS = 24
# Anchored: identifier must start with claude/codex, allowing an npm scope first.
# We deliberately do NOT match file paths — "pkgs/claude-utils-fork.nix" should
# not exempt an unrelated package.
EXEMPT_RE = re.compile(r"^(@[^/]+/)?(claude|codex)", re.IGNORECASE)
NPM_REGISTRY = "https://registry.npmjs.org"


class Registry:
    def __init__(self):
        self._cache = {}
        self._github_token = os.environ.get("GITHUB_TOKEN") or self._read_gh_token()

    def _read_gh_token(self):
        try:
            result = subprocess.run(
                ["gh", "auth", "token"],
                check=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                timeout=5,
            )
        except (OSError, subprocess.SubprocessError):
            return ""
        return result.stdout.strip() if result.returncode == 0 else ""

    def json(self, url):
        if url not in self._cache:
            headers = {"Accept": "application/json"}
            if self._github_token and urllib.parse.urlparse(url).netloc == "api.github.com":
                headers["Authorization"] = f"Bearer {self._github_token}"
            request = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(request, timeout=20) as response:
                self._cache[url] = json.load(response)
        return self._cache[url]


def parse_rfc3339(value):
    if value.endswith("Z"):
        value = value[:-1] + "+00:00"
    return datetime.fromisoformat(value).astimezone(timezone.utc)


def age_hours(dt, now):
    return (now - dt).total_seconds() / 3600


def is_exempt(*parts):
    return any(EXEMPT_RE.search(str(part or "")) for part in parts)


def npm_publish_time(registry, package, version):
    encoded = urllib.parse.quote(package, safe="@")
    metadata = registry.json(f"{NPM_REGISTRY}/{encoded}")
    published = metadata.get("time", {}).get(version)
    if not published:
        raise RuntimeError(f"npm:{package}@{version}: missing publish time")
    return parse_rfc3339(published)


def iter_package_nix(repo):
    # Picks up both pkgs/<name>.nix and pkgs/<name>/default.nix so subdir
    # packages (e.g. claude-code-acp, portless) aren't silently skipped.
    pkgs_dir = repo / "pkgs"
    yield from sorted(pkgs_dir.glob("*.nix"))
    yield from sorted(pkgs_dir.glob("*/default.nix"))


def iter_nix_npm_fetches(repo):
    version_re = re.compile(r'^\s*version = "([^"]+)";', re.MULTILINE)
    url_re = re.compile(r'https://registry\.npmjs\.org/([^"\s]+)/-/[^"\s]+-\$\{version\}\.tgz')
    npm_arch_re = re.compile(r'^\s*npmArch = "([^"]+)";', re.MULTILINE)
    for path in iter_package_nix(repo):
        rel = path.relative_to(repo).as_posix()
        text = path.read_text(encoding="utf-8")
        version_match = version_re.search(text)
        url_match = url_re.search(text)
        if not version_match or not url_match:
            continue
        version = version_match.group(1)
        package_template = urllib.parse.unquote(url_match.group(1))
        if "${source.npmArch}" in package_template:
            packages = [
                package_template.replace("${source.npmArch}", arch)
                for arch in sorted(set(npm_arch_re.findall(text)))
            ]
        else:
            packages = [package_template]
        for package in packages:
            yield {
                "kind": "nix-npm",
                "name": f"{package}@{version}",
                "source": rel,
                "exempt": is_exempt(package),
                "published": lambda registry, p=package, v=version: npm_publish_time(registry, p, v),
            }


def iter_flake_inputs(repo):
    lock_path = repo / "flake.lock"
    if not lock_path.exists():
        return
    with lock_path.open(encoding="utf-8") as f:
        lock = json.load(f)
    for name, node in lock.get("nodes", {}).items():
        locked = node.get("locked", {})
        last_modified = locked.get("lastModified")
        if not isinstance(last_modified, int):
            continue
        owner = locked.get("owner")
        repo_name = locked.get("repo")
        rev = locked.get("rev", "")
        label = name
        if owner and repo_name:
            label = f"{name} ({owner}/{repo_name}@{rev[:12]})"
        yield {
            "kind": "flake",
            "name": label,
            "source": "flake.lock",
            "exempt": is_exempt(name, owner, repo_name),
            "published": lambda _registry, lm=last_modified: datetime.fromtimestamp(lm, timezone.utc),
        }


def nix_attr(text, field):
    match = re.search(rf'^\s*{re.escape(field)} = "([^"]+)";', text, re.MULTILINE)
    return match.group(1) if match else None


def iter_nix_github_fetches(repo):
    owner_re = re.compile(r'^\s*owner = "([^"]+)";', re.MULTILINE)
    repo_re = re.compile(r'^\s*repo = "([^"]+)";', re.MULTILINE)
    for path in iter_package_nix(repo):
        rel = path.relative_to(repo).as_posix()
        text = path.read_text(encoding="utf-8")
        if "fetchFromGitHub" not in text:
            continue
        owner_match = owner_re.search(text)
        repo_match = repo_re.search(text)
        version = nix_attr(text, "version")
        if not owner_match or not repo_match or not version:
            continue
        owner = owner_match.group(1)
        repo_name = repo_match.group(1)
        rev = f"v{version}"
        yield {
            "kind": "nix-github",
            "name": f"{owner}/{repo_name}@{rev}",
            "source": rel,
            "exempt": is_exempt(owner, repo_name),
            "published": lambda registry, o=owner, r=repo_name, ref=rev: github_commit_time(registry, o, r, ref),
        }


def iter_nix_github_release_fetches(repo):
    version_re = re.compile(r'^\s*version = "([^"]+)";', re.MULTILINE)
    url_re = re.compile(
        r'https://github\.com/([^/"\s]+)/([^/"\s]+)/releases/download/((?:[^/"\s]+/)?)v\$\{version\}/([^"\s]+)'
    )
    for path in iter_package_nix(repo):
        rel = path.relative_to(repo).as_posix()
        text = path.read_text(encoding="utf-8")
        version_match = version_re.search(text)
        url_match = url_re.search(text)
        if not version_match or not url_match:
            continue
        version = version_match.group(1)
        owner, repo_name, tag_prefix, asset = url_match.groups()
        yield {
            "kind": "nix-github-release",
            "name": f"{owner}/{repo_name}@v{version}/{asset}",
            "source": rel,
            "exempt": is_exempt(owner, repo_name),
            "published": lambda registry, o=owner, r=repo_name, p=tag_prefix, v=version: github_release_time(
                registry, o, r, f"{p}v{v}"
            ),
        }


def iter_cursor_fetches(repo):
    path = repo / "pkgs" / "cursor-cli.nix"
    if not path.exists():
        return
    rel = path.relative_to(repo).as_posix()
    text = path.read_text(encoding="utf-8")
    release = nix_attr(text, "release")
    version = nix_attr(text, "version")
    if not release or not version or "downloads.cursor.com/lab/${release}" not in text:
        return
    yield {
        "kind": "cursor-lab",
        "name": f"cursor-cli@{release}",
        "source": rel,
        "exempt": is_exempt("cursor-cli"),
        "published": lambda _registry, r=release: cursor_release_time(r),
    }


def github_commit_time(registry, owner, repo_name, ref):
    metadata = registry.json(f"https://api.github.com/repos/{owner}/{repo_name}/commits/{ref}")
    date = metadata.get("commit", {}).get("committer", {}).get("date")
    if not date:
        raise RuntimeError(f"github:{owner}/{repo_name}@{ref}: missing commit date")
    return parse_rfc3339(date)


def github_release_time(registry, owner, repo_name, tag):
    encoded_tag = urllib.parse.quote(tag, safe="")
    metadata = registry.json(f"https://api.github.com/repos/{owner}/{repo_name}/releases/tags/{encoded_tag}")
    published = metadata.get("published_at")
    if not published:
        raise RuntimeError(f"github:{owner}/{repo_name}@{tag}: missing release publish time")
    return parse_rfc3339(published)


def cursor_release_time(release):
    match = re.match(r"^(\d{4})\.(\d{2})\.(\d{2})-", release)
    if not match:
        raise RuntimeError(f"cursor-cli:{release}: missing date prefix")
    year, month, day = map(int, match.groups())
    return datetime(year, month, day, tzinfo=timezone.utc)


def main():
    parser = argparse.ArgumentParser(description="Block dependency pins that are too new.")
    parser.add_argument("--repo", default=".", help="repository root")
    parser.add_argument(
        "--min-age-hours",
        type=float,
        default=float(os.environ.get("PIX_DEPENDENCY_MIN_AGE_HOURS", DEFAULT_MIN_AGE_HOURS)),
    )
    parser.add_argument(
        "--allow-fresh",
        action="store_true",
        default=bool(os.environ.get("PIX_ALLOW_FRESH_DEPS")),
        help="report fresh dependencies but exit successfully",
    )
    parser.add_argument(
        "--reason",
        default=os.environ.get("PIX_FRESH_DEPS_REASON", ""),
        help="reason for allowing fresh dependencies",
    )
    args = parser.parse_args()

    if args.allow_fresh and not args.reason:
        print("fresh dependency bypass requires --reason or PIX_FRESH_DEPS_REASON", file=sys.stderr)
        return 2

    repo = Path(args.repo).resolve()
    registry = Registry()
    now = datetime.now(timezone.utc)
    fresh = []
    errors = []
    checked = 0
    exempt = 0

    entries = []
    entries.extend(iter_flake_inputs(repo))
    entries.extend(iter_nix_npm_fetches(repo))
    entries.extend(iter_nix_github_fetches(repo))
    entries.extend(iter_nix_github_release_fetches(repo))
    entries.extend(iter_cursor_fetches(repo))

    seen = set()
    for entry in entries:
        key = (entry["kind"], entry["name"], entry["source"])
        if key in seen:
            continue
        seen.add(key)
        if entry["exempt"]:
            exempt += 1
            continue
        checked += 1
        try:
            published = entry["published"](registry)
        except Exception as exc:
            print(
                f"freshness check failed for {entry['source']} {entry['name']}: {exc}",
                file=sys.stderr,
            )
            errors.append(entry)
            continue
        hours = age_hours(published, now)
        if hours < args.min_age_hours:
            fresh.append((entry, published, hours))

    if errors:
        print("dependencies could not be verified:", file=sys.stderr)
        for entry in errors:
            print(f"- {entry['source']}: {entry['name']}", file=sys.stderr)

    if fresh:
        print(f"dependencies newer than {args.min_age_hours:g}h:")
        for entry, published, hours in fresh:
            print(
                f"- {entry['source']}: {entry['name']} "
                f"published {published.isoformat()} ({hours:.1f}h old)"
            )
    if fresh or errors:
        if errors:
            return 2
        if args.allow_fresh:
            print(f"fresh dependency bypassed: {args.reason}")
            return 0
        return 1

    print(f"dependency freshness ok: checked {checked}, exempted {exempt}, floor {args.min_age_hours:g}h")
    return 0


if __name__ == "__main__":
    sys.exit(main())
