{ lib, buildGoModule, fetchFromGitHub, go_1_26 }:

(buildGoModule.override { go = go_1_26; }) rec {
  pname = "gogcli";
  version = "0.19.0";

  src = fetchFromGitHub {
    owner = "openclaw";
    repo = "gogcli";
    rev = "v${version}";
    hash = "sha256-8+ojZUNsmAzFQbdTG0eE/FG6nbptq49QZqjrCP1RhE4=";
  };

  vendorHash = "sha256-fkvMTJmYRsknDDffrZq2L2GRYDozwPX0yv7K84n5a84=";

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
