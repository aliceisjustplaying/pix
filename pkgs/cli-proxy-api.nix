{ lib, buildGoModule, fetchFromGitHub, go_1_26 }:

(buildGoModule.override { go = go_1_26; }) rec {
  pname = "cli-proxy-api";
  version = "7.1.19";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-Fzc1jXvTVrnTfO4tuEtRjBSUYivqpGDZUIbLQQxaG+k=";
  };

  vendorHash = "sha256-AIue9XBsfsKGClRLB1DCME+36crapnOdQrEICFYG1a0=";

  # Upstream v7.1.19 ships a test file that still imports the old `v6` module
  # path (a stale find-and-replace miss from the version bump). Vendoring
  # resolves test deps, so fix the import to v7 before the module fetch.
  overrideModAttrs = _: {
    postPatch = ''
      substituteInPlace sdk/cliproxy/auth/request_auth_prepare_test.go \
        --replace-fail "CLIProxyAPI/v6/" "CLIProxyAPI/v7/"
    '';
  };

  subPackages = [ "cmd/server" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
  ];

  postInstall = ''
    mv $out/bin/server $out/bin/cli-proxy-api
  '';

  meta = {
    description = "OpenAI/Gemini/Claude/Codex compatible OAuth proxy service for AI CLIs";
    homepage = "https://github.com/router-for-me/CLIProxyAPI";
    license = lib.licenses.mit;
    mainProgram = "cli-proxy-api";
  };
}
