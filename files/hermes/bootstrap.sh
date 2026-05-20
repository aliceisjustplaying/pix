#!/usr/bin/env bash
set -euo pipefail

mkdir -p "@hermesHome@" \
	"@hermesOverrides@" \
	"@hermesHome@/plugins/agentmemory" \
	"@hermesHome@/logs" \
	"@hermesHome@/sessions" \
	"@hermesHome@/skills" \
	"@hermesHome@/pairing" \
	"@hermesHome@/bin" \
	"/workspace/src"

if [ ! -d "@hermesRepo@/.git" ]; then
	rm -rf "@hermesRepo@"
	git clone --depth=1 https://github.com/NousResearch/hermes-agent.git "@hermesRepo@"
fi

install -m 600 "@hermesSitecustomize@" "@hermesOverrides@/sitecustomize.py"
install -m 600 "@agentmemoryMemoryProvider@" "@hermesHome@/plugins/agentmemory/__init__.py"
install -m 700 "@hermesLive@" "@hermesHome@/bin/hermes-live"
printf 'nixos\n' >"@hermesHome@/.managed"
chmod 600 "@hermesHome@/.managed"

if [ ! -f "@hermesHome@/config.yaml" ]; then
	install -m 600 "@hermesConfig@" "@hermesHome@/config.yaml"
fi

if [ ! -f "@hermesHome@/.env" ]; then
	api_server_key="$(@coreutilsBin@/head -c 32 /dev/urandom | @coreutilsBin@/od -An -tx1 | @coreutilsBin@/tr -d ' \n')"
	@gnusedBin@/sed "s|@apiServerKey@|$api_server_key|g" "@hermesEnvTemplate@" >"@hermesHome@/.env"
	chmod 600 "@hermesHome@/.env"
fi

rev="$(git -C "@hermesRepo@" rev-parse HEAD)"
stamp="@hermesHome@/.install-rev"

if [ ! -x "@hermesVenv@/bin/hermes" ] || [ ! -f "$stamp" ] || [ "$(cat "$stamp")" != "$rev" ]; then
	rm -rf "@hermesVenv@"
	@uv@ venv "@hermesVenv@" --python @python@
	(
		cd "@hermesRepo@"
		export UV_PROJECT_ENVIRONMENT="@hermesVenv@"
		@uv@ sync \
			--extra messaging \
			--extra cron \
			--extra cli \
			--extra pty \
			--extra honcho \
			--extra mcp \
			--extra acp
	)
	printf '%s\n' "$rev" >"$stamp"
	chmod 600 "$stamp"
fi

mkdir -p "@hermesSitePackages@"
install -m 600 "@hermesPth@" "@hermesSitePackages@/hermes-home-overrides.pth"

"@python@" - "@hermesHome@/config.yaml" "@agentmemoryMcp@" <<'PY'
from __future__ import annotations

import sys
from pathlib import Path

config_path = Path(sys.argv[1])
agentmemory_mcp = sys.argv[2]
text = config_path.read_text()
lines = text.splitlines()


def set_memory_provider(src: list[str]) -> list[str]:
    out = list(src)
    for i, line in enumerate(out):
        if line == "memory:":
            j = i + 1
            provider_idx = None
            while j < len(out) and (out[j].startswith(" ") or not out[j].strip()):
                if out[j].startswith("  provider:"):
                    provider_idx = j
                j += 1
            if provider_idx is None:
                out.insert(j, "  provider: agentmemory")
            else:
                out[provider_idx] = "  provider: agentmemory"
            return out
    return out + ["memory:", "  provider: agentmemory"]


def set_agentmemory_mcp(src: list[str]) -> list[str]:
    block = [
        "  agentmemory:",
        f"    command: {agentmemory_mcp}",
        "    args: []",
        "    env:",
        "      AGENTMEMORY_URL: http://127.0.0.1:3111",
        "      AGENTMEMORY_FORCE_PROXY: \"1\"",
    ]
    out = list(src)
    for i, line in enumerate(out):
        if line == "mcp_servers:":
            j = i + 1
            while j < len(out) and (out[j].startswith(" ") or not out[j].strip()):
                j += 1
            k = i + 1
            while k < j:
                if out[k] == "  agentmemory:":
                    end = k + 1
                    while end < len(out) and (out[end].startswith("    ") or not out[end].strip()):
                        end += 1
                    out[k:end] = block
                    return out
                k += 1
            out[i + 1:i + 1] = block
            return out
    return out + ["mcp_servers:", *block]


def remove_named_mcp(src: list[str], name: str) -> list[str]:
    marker = f"  {name}:"
    out: list[str] = []
    i = 0
    while i < len(src):
        if src[i] == marker:
            i += 1
            while i < len(src) and (src[i].startswith("    ") or not src[i].strip()):
                i += 1
            continue
        out.append(src[i])
        i += 1
    return out


updated = set_agentmemory_mcp(remove_named_mcp(set_memory_provider(lines), "hindsight"))
new_text = "\n".join(updated) + "\n"
if new_text != text:
    config_path.write_text(new_text)
PY
