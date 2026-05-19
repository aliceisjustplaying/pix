{ lib, stdenv, fetchurl, nodejs_24, makeWrapper }:

stdenv.mkDerivation rec {
  pname = "gemini-cli";
  version = "0.42.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@google/gemini-cli/-/gemini-cli-${version}.tgz";
    hash = "sha512-LfqKztXeB2hWRVWVmPQdmVnub04LDPoN4fAPep7zCQ84UzLUyFFGymY6Uh25Ffb130Yq20r+hoF/ePdJgz9tbw==";
  };

  sourceRoot = "package";

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/gemini-cli
    cp -R bundle LICENSE package.json $out/lib/gemini-cli/
    makeWrapper ${nodejs_24}/bin/node $out/bin/gemini \
      --add-flags "$out/lib/gemini-cli/bundle/gemini.js"

    runHook postInstall
  '';

  meta = {
    description = "Gemini CLI";
    homepage = "https://github.com/google-gemini/gemini-cli";
    license = lib.licenses.asl20;
    platforms = lib.platforms.linux;
    mainProgram = "gemini";
  };
}
