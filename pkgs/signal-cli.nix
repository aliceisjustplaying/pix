{
  fetchurl,
  signal-cli,
}:

signal-cli.overrideAttrs (_old: rec {
  version = "0.14.4.1";

  src = fetchurl {
    url = "https://github.com/AsamK/signal-cli/releases/download/v${version}/signal-cli-${version}.tar.gz";
    hash = "sha256-nLDYG20UOrihpcNRpv6KWRMDEIw3KccTKy5MEjID1X8=";
  };
})
