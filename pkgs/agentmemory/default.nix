{ buildNpmPackage, fetchurl, lib, makeWrapper, nodejs_24 }:

buildNpmPackage rec {
  pname = "agentmemory";
  version = "0.9.20";

  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-${version}.tgz";
    hash = "sha512-Q0wddHD78Rd06GbiaXPIRnAY7tNo2+4UphNd02UD1f5lAyDp6AKXon36aoBv7o0Iv/Phx6xClqL8yboFvCMKjA==";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [ "--legacy-peer-deps" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  npmDepsHash = "sha256-EntwiJ0qs+esTMwRxlwiFtYCDEQ8DQKyH4eOK5NtYW4=";

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
