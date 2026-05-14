{ lib, buildGoModule, fetchFromGitHub, go_1_26 }:

(buildGoModule.override { go = go_1_26; }) rec {
  pname = "cli-proxy-api";
  version = "7.0.4";

  src = fetchFromGitHub {
    owner = "router-for-me";
    repo = "CLIProxyAPI";
    rev = "v${version}";
    hash = "sha256-LvKTPKtzz3m/B5R2EgU1dUlRO/zaJcIRtv+pDKkXBSg=";
  };

  vendorHash = "sha256-AIue9XBsfsKGClRLB1DCME+36crapnOdQrEICFYG1a0=";

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
