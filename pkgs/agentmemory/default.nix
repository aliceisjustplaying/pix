{ buildNpmPackage, fetchurl, lib, makeWrapper, nodejs_24 }:

buildNpmPackage rec {
  pname = "agentmemory";
  version = "0.9.22";

  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-${version}.tgz";
    hash = "sha512-oLFaulIbdv5l7xXAn3GvCVEz6xBi+PRKEXd2ClfnzW846tGz3GjG4WrRgdHmyXz+wwAp4BP/ISXOwN3xRdMMCQ==";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [ "--legacy-peer-deps" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  npmDepsHash = "sha256-PPM0d8wPW1Tv+cAGa+1qyh7PPgd9iQgp2Jq61YoamIA=";

  dontNpmBuild = true;

  postInstall = ''
    makeWrapper $out/bin/agentmemory $out/bin/agentmemory-mcp --add-flags mcp
  '';

  meta = with lib; {
    description = "Persistent memory for AI coding agents";
    homepage = "https://github.com/rohitg00/agentmemory";
    license = licenses.asl20;
    mainProgram = "agentmemory";
    platforms = platforms.linux;
  };
}
