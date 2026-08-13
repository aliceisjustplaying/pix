#!/usr/bin/env bash
set -euo pipefail
export HERMES_HOME=/workspace/.hermes
export PYTHONPATH=/workspace/.hermes/overrides${PYTHONPATH:+:$PYTHONPATH}
export LD_LIBRARY_PATH=@hermesLibraryPath@${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
export SSL_CERT_FILE=@caBundle@
export NIX_SSL_CERT_FILE=@caBundle@
export PATH=@hermesBuildPath@${PATH:+:$PATH}

if [ "$#" -ge 2 ] && [ "$1" = "gateway" ] && [ "$2" = "restart" ]; then
	exec sudo -n systemctl restart hermes-gateway.service
fi

exec /workspace/.hermes/venv/bin/hermes "$@"
