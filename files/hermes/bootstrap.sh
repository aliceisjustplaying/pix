set -euo pipefail

mkdir -p "@hermesHome@" \
	"@hermesOverrides@" \
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
install -m 700 "@hermesLive@" "@hermesHome@/bin/hermes-live"

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
