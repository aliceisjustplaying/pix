set -euo pipefail
cd @workspaceSrc@/piclaw-customizations
runuser -u agent -- env HOME=@agentHome@ git pull --ff-only
./scripts/piclaw-update-host.sh --force
