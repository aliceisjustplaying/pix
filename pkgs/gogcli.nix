{ lib, buildGoModule, fetchFromGitHub, go_1_26 }:

(buildGoModule.override { go = go_1_26; }) rec {
  pname = "gogcli";
  version = "0.31.1";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "gogcli";
    rev = "v${version}";
    hash = "sha256-kTMxHPY3bv85X3H0TQGHLvL/nVVjh5fDF/S/z6Xd+bw=";
  };

  vendorHash = "sha256-fof2DVm6Cn1ZW7gKSYLHX6M6nPbtYBn6EKinptjhhrE=";

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
