install -m 0400 -o agent -g users \
	@githubCloneKeyPath@ \
	@agentHome@/.ssh/id_ed25519_github

install -m 0400 -o agent -g users \
	@gogOAuthClientJsonPath@ \
	@agentHome@/.config/gog/oauth-client.json

install -m 0400 -o agent -g users \
	@agentWebSearchJsonPath@ \
	@agentHome@/.pi/web-search.json
