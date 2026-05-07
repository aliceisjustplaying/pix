set -euo pipefail
mkdir -p "@webuiState@" /workspace/src
if [ ! -d "@webuiRepo@/.git" ]; then
	rm -rf "@webuiRepo@"
	@git@ clone --depth=1 https://github.com/nesquena/hermes-webui.git "@webuiRepo@"
else
	@git@ -C "@webuiRepo@" reset --hard HEAD
	@git@ -C "@webuiRepo@" pull --ff-only || true
fi
