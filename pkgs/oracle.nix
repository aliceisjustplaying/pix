{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "oracle";
  version = "0.14.0";

  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@steipete/oracle/-/oracle-${version}.tgz";
    hash = "sha512-tqbz8R7N7jetJXyFEMQh/DidcPF90tsW2gQNtxcaUe6HnSF/z5/c8nM42GdDWkHvzgb2qOea4R0gBkvI1Wm0qg==";
  };

  postPatch = ''
    cp ${./oracle-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-Cqvxm74gRX4R024gkrl/570T6+fZzdMW7IEjniRZB6M=";

  dontNpmBuild = true;
  npmFlags = [ "--legacy-peer-deps" ];
  npmPackFlags = [ "--ignore-scripts" ];

  meta = with lib; {
    description = "CLI wrapper around OpenAI Responses API and ChatGPT browser automation";
    homepage = "https://askoracle.sh";
    license = licenses.mit;
    mainProgram = "oracle";
    platforms = platforms.linux;
  };
}
