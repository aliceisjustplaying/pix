{ lib, stdenv, fetchurl, nodejs, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "sourcegraph-amp";
  version = "0.0.1779729291-gfe2d7f";

  src = fetchurl {
    url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${version}.tgz";
    hash = "sha512-7G3XYek7wT/zalrdhwo1vHZj1k+W5/qlj6eZsXEzbTnCVnfom3CzJP3yU7/AI2VoIX2DEb37ruS76Yf5/iN55g==";
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
