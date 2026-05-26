{ buildNpmPackage, fetchurl, lib, makeWrapper, nodejs_24 }:

buildNpmPackage rec {
  pname = "agentmemory";
  version = "0.9.21";

  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-${version}.tgz";
    hash = "sha512-WLS0nfnmr9k//2pSQNhBDYUxZdrlumRfQFL9+0p9UQxWH/jmTbnnsUyeUlAu4lxCaOSyCnzr885jHAEKIbVsmw==";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [ "--legacy-peer-deps" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  npmDepsHash = "sha256-YgdB524q2MFWB1bnzM7f0RAgsq/B47jhOaYX5GOMu1I=";

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
