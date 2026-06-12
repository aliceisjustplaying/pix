{ buildNpmPackage, fetchurl, lib, makeWrapper, nodejs_24 }:

buildNpmPackage rec {
  pname = "agentmemory";
  version = "0.9.27";

  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-${version}.tgz";
    hash = "sha512-3IZ8j41gUBoQnMtoRlSHda3mEBYPh1TxZ9xgTi4zqEWDFu0ZrEhCm76C8t13mIAQA2M2R1GtD7t9OcU3nsyTgw==";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [ "--legacy-peer-deps" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  npmDepsHash = "sha256-YfvuMgbSFLROi8Au/G143Mgcy1TwpTv51jt4E21sEpM=";

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
