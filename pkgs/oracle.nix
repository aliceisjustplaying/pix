{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "oracle";
  version = "0.16.0";

  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@steipete/oracle/-/oracle-${version}.tgz";
    hash = "sha512-eTMsoKJZooapRa+agFARv/4KF1uiAZmfD8ucCyRBC42joHZCD9mXBa1E7vtFkVFq1uvDJapOA8r/c8LcW/1FPg==";
  };

  postPatch = ''
    cp ${./oracle-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-p7wQHBOV6Tk9H/PBiERT6/0Rgi6NL+R81Zg3vxLuslA=";

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
