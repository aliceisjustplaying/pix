{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "oracle";
  version = "0.13.0";

  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@steipete/oracle/-/oracle-${version}.tgz";
    hash = "sha512-983uazltJ5uhODl374w5xIGi5JjcimpsfVyaSt7knAmdDoxtZzAV9inQjpQc/dOjoQ34nREqvJT27Ii2ez2hQA==";
  };

  postPatch = ''
    cp ${./oracle-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-eUQQYvQ8uzeNrof8/kUtUO+K2C6uVqIWahBQsuIBwWk=";

  dontNpmBuild = true;
  npmPackFlags = [ "--ignore-scripts" ];

  meta = with lib; {
    description = "CLI wrapper around OpenAI Responses API and ChatGPT browser automation";
    homepage = "https://askoracle.sh";
    license = licenses.mit;
    mainProgram = "oracle";
    platforms = platforms.linux;
  };
}
