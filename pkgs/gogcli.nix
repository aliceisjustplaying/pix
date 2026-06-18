{ lib, buildGoModule, fetchFromGitHub, go_1_26 }:

(buildGoModule.override { go = go_1_26; }) rec {
  pname = "gogcli";
  version = "0.28.0";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "gogcli";
    rev = "v${version}";
    hash = "sha256-qXeRxZQkDwVRuXWkAPI3Yr1pQpZmmVX2SQS8UdBQGYo=";
  };

  vendorHash = "sha256-JrRIUYpw2lAD0ezi0HTZvS42OS7vP8DAHU3m0u3eCbM=";

  subPackages = [ "cmd/gog" ];

  ldflags = [
    "-s"
    "-w"
    "-X github.com/steipete/gogcli/internal/cmd.version=v${version}"
  ];

  meta = {
    description = "Google Workspace CLI for terminals, scripts, CI, and coding agents";
    homepage = "https://github.com/openclaw/gogcli";
    license = lib.licenses.mit;
    mainProgram = "gog";
  };
}
