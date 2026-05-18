set -euo pipefail

install -d -m 0700 -o agent -g users /home/agent/.agentmemory

if [ ! -f /home/agent/.agentmemory/preferences.json ]; then
	install -m 0600 -o agent -g users /dev/null /home/agent/.agentmemory/preferences.json
	cat >/home/agent/.agentmemory/preferences.json <<'JSON'
{
  "schemaVersion": 1,
  "lastAgent": "hermes",
  "lastAgents": ["hermes"],
  "lastProvider": "openai",
  "skipSplash": true,
  "skipNpxHint": true,
  "skipGlobalInstall": true,
  "skipConsoleInstall": true,
  "firstRunAt": "1970-01-01T00:00:00.000Z"
}
JSON
	chown agent:users /home/agent/.agentmemory/preferences.json
	chmod 0600 /home/agent/.agentmemory/preferences.json
fi

if [ ! -f /home/agent/.agentmemory/.env ]; then
	install -m 0600 -o agent -g users /dev/null /home/agent/.agentmemory/.env
	cat >/home/agent/.agentmemory/.env <<'ENV'
AGENTMEMORY_III_VERSION=0.11.2
AGENTMEMORY_URL=http://127.0.0.1:3111
AGENTMEMORY_VIEWER_URL=http://127.0.0.1:3113
AGENTMEMORY_AUTO_COMPRESS=true
AGENTMEMORY_INJECT_CONTEXT=false
EMBEDDING_PROVIDER=local
III_REST_PORT=3111
III_STREAMS_PORT=3112
III_ENGINE_URL=ws://127.0.0.1:49134
OPENAI_API_KEY=CLI_PROXY_API_KEY
OPENAI_BASE_URL=http://127.0.0.1:8317/v1
OPENAI_MODEL=anthropic/claude-haiku-4.5
ENV
	chown agent:users /home/agent/.agentmemory/.env
	chmod 0600 /home/agent/.agentmemory/.env
fi
