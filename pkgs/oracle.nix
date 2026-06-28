{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "oracle";
  version = "0.15.0";

  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@steipete/oracle/-/oracle-${version}.tgz";
    hash = "sha512-aXHLYk2y6rsx3IGBgwzZM+5yjEoRaAxfAb5/ZzRIu++Cr6G5LIXTHUnVEu4xI/AMit0pj9nKAJkFXW5RdP7rnw==";
  };

  postPatch = ''
    cp ${./oracle-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-RSxmxy+1EYfsDTbOvgVCHhXR1HijTzQzfjmbpPi7v0g=";

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
