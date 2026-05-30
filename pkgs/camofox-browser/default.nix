{
  buildNpmPackage,
  fetchurl,
  lib,
  makeWrapper,
  python3,
  nodejs_24,
}:

buildNpmPackage rec {
  pname = "camofox-browser";
  version = "1.11.2";

  nodejs = nodejs_24;
  nativeBuildInputs = [
    makeWrapper
    python3
  ];

  src = fetchurl {
    url = "https://registry.npmjs.org/@askjo/camofox-browser/-/camofox-browser-${version}.tgz";
    hash = "sha512-zllDDHl2aht8XAQngAKYY5SowjK4yz0HAQGp9OrWoYkOofS0kZKVkr3O+SoVebAv19edO4ZZ0OUQAcb3vs/guw==";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [ "--legacy-peer-deps" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  npmDepsHash = "sha256-hgKj0i/jJStE411kgH+h20DQLy477gXIPGrFHOWLBEw=";

  CAMOFOX_SKIP_DOWNLOAD = "1";
  PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";

  dontNpmBuild = true;

  postInstall = ''
    pushd $out/lib/node_modules/@askjo/camofox-browser
    # camoufox-js compares only the alpha/beta release suffix, which makes
    # newer Firefox-major alpha builds look older than the old beta.24 build.
    substituteInPlace node_modules/camoufox-js/dist/__version__.js \
      --replace-fail 'static MIN_VERSION = "beta.19";' 'static MIN_VERSION = "alpha.0";'
    npm rebuild better-sqlite3 --build-from-source --offline --nodedir=${nodejs_24.dev}
    popd

    makeWrapper ${nodejs_24}/bin/node $out/bin/camofox-browser \
      --add-flags $out/lib/node_modules/@askjo/camofox-browser/server.js
  '';

  meta = {
    description = "Anti-detection browser REST API powered by Camoufox";
    homepage = "https://github.com/jo-inc/camofox-browser";
    license = lib.licenses.mit;
    mainProgram = "camofox-browser";
    platforms = lib.platforms.linux;
  };
}
