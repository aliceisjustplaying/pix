{ lib, buildGoModule, fetchFromGitHub, go_1_26 }:

(buildGoModule.override { go = go_1_26; }) rec {
  pname = "gogcli";
  version = "0.21.0";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "gogcli";
    rev = "v${version}";
    hash = "sha256-V7kTXdLO2zsf69d4QV+7tGelQUYzaOMhDE17tffokts=";
  };

  vendorHash = "sha256-ElQF27p/kDaRSCwUuWLHV4AJ36ZlNI0OmqemmiJHBkE=";

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
