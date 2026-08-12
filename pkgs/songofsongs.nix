{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  makeWrapper,
  nodejs,
}:

buildNpmPackage rec {
  pname = "songofsongs";
  version = "1.0.0-unstable-2023-04-10";

  src = fetchFromGitHub {
    owner = "aliceisjustplaying";
    repo = "songofsongs-bot-bsky";
    rev = "4c69c464639543bb609c7ecf026a0a1d32d16817";
    hash = "sha256-gzG7tLToc+QflbRjHiaCiToVSfWNIdnKbPA5k73UNaE=";
  };

  npmDepsHash = "sha256-zf9Ye0WkSYxgpmC5AONw7DeX8RO37ba+xneEZ732D+o=";
  dontNpmBuild = true;

  patches = [ ./songofsongs-state-dir.patch ];
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -d "$out/bin" "$out/libexec/songofsongs" "$out/share/songofsongs"
    cp -r node_modules "$out/libexec/songofsongs/"
    cp index.ts package.json "$out/libexec/songofsongs/"
    mv "$out/libexec/songofsongs/index.ts" "$out/libexec/songofsongs/index.js"
    install -m 0444 songofsongs.txt "$out/share/songofsongs/songofsongs.txt"

    makeWrapper ${nodejs}/bin/node "$out/bin/songofsongs" \
      --add-flags "$out/libexec/songofsongs/index.js" \
      --set SONGOFSONGS_SOURCE_FILE "$out/share/songofsongs/songofsongs.txt"

    runHook postInstall
  '';

  meta = {
    description = "Bluesky bot posting lines from Song of Songs";
    homepage = "https://github.com/aliceisjustplaying/songofsongs-bot-bsky";
    license = lib.licenses.isc;
    mainProgram = "songofsongs";
    platforms = lib.platforms.unix;
  };
}
