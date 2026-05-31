{ lib, stdenv, fetchurl, nodejs, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "sourcegraph-amp";
  version = "0.0.1780143526-gc351d5";

  src = fetchurl {
    url = "https://registry.npmjs.org/@sourcegraph/amp/-/amp-${version}.tgz";
    hash = "sha512-m3LXi69QpeXE8MNKvk1zX89e6xsML5lOMgQy5o7HKCQbBaevOeKED2NaDw15PF3nV08ZJ+KkhghRjWip4gv5kg==";
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
