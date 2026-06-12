{ lib, buildGoModule, fetchFromGitHub, go_1_26 }:

(buildGoModule.override { go = go_1_26; }) rec {
  pname = "gogcli";
  version = "0.24.0";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "gogcli";
    rev = "v${version}";
    hash = "sha256-mepQo/4OMFuCM71XsyGFIc2PBWqLA8ZXPa1jKGxDfGk=";
  };

  vendorHash = "sha256-JDMaMa4/Sjul7ClzlnU8IaQle8zNo6S+5jpnkJvArNg=";

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
