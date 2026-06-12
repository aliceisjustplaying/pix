{
  fetchurl,
  signal-cli,
}:

signal-cli.overrideAttrs (_old: rec {
  version = "0.14.5";

  src = fetchurl {
    url = "https://github.com/AsamK/signal-cli/releases/download/v${version}/signal-cli-${version}.tar.gz";
    hash = "sha256-YtOOv+85iNePQ35zKBg7de5UnRETguZsGvcNPr0816c=";
  };
})
