{ lib, stdenv, fetchurl, nodejs, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "sourcegraph-amp";
  version = "0.0.1780827515-ga4daec";

  src = fetchurl {
    url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${version}.tgz";
    hash = "sha512-J1nGeiInZN76fAAr6ywtFxScgmHm5rmPxfMVP1hHg5ie0mChZbhwqh4kudyfm9GskiIzSPPvmP5eRcvcOELFJg==";
  };

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/amp
    cp -R dist LICENSE.md README.md package.json $out/lib/amp/
    makeWrapper ${nodejs}/bin/node $out/bin/amp \
      --add-flags "$out/lib/amp/dist/main.js"

    runHook postInstall
  '';

  meta = {
    description = "CLI for Amp, the frontier coding agent";
    homepage = "https://ampcode.com";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
    mainProgram = "amp";
  };
}
