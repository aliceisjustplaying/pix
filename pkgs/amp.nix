{ lib, stdenv, fetchurl, nodejs, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "sourcegraph-amp";
  version = "0.0.1778531432-g3bd093";

  src = fetchurl {
    url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${version}.tgz";
    hash = "sha512-fLlXOha+lZe5rIeGda8Kfujx3eGApHM5Fi2WgdiaWnzGhsw7qYnnebgyKCZYa0FEXEmwy3SrceF0UnVpN//c+Q==";
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
