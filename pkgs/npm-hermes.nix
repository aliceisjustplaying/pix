{
  fetchurl,
  lib,
  makeWrapper,
  nodejs_24,
  stdenvNoCC,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "npm-hermes";
  version = "11.17.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/npm/-/npm-${finalAttrs.version}.tgz";
    hash = "sha256-spC7s1uecsPvhO2+BB8oxEecTZ7nn1VYF7jKr+fOS7o=";
  };

  nativeBuildInputs = [ makeWrapper ];

  sourceRoot = "package";
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules/npm" "$out/bin"
    cp -R . "$out/lib/node_modules/npm"

    makeWrapper ${nodejs_24}/bin/node "$out/bin/npm" \
      --add-flags "$out/lib/node_modules/npm/bin/npm-cli.js" \
      --prefix PATH : ${lib.makeBinPath [ nodejs_24 ]}
    makeWrapper ${nodejs_24}/bin/node "$out/bin/npx" \
      --add-flags "$out/lib/node_modules/npm/bin/npx-cli.js" \
      --prefix PATH : ${lib.makeBinPath [ nodejs_24 ]}

    runHook postInstall
  '';

  meta = {
    description = "npm version accepted by the Hermes Agent engine range";
    homepage = "https://www.npmjs.com/package/npm";
    license = lib.licenses.artistic2;
    platforms = lib.platforms.unix;
  };
})
