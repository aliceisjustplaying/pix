{ buildNpmPackage, fetchurl, lib, makeWrapper, nodejs_24 }:

buildNpmPackage rec {
  pname = "agentmemory";
  version = "0.9.24";

  nodejs = nodejs_24;
  nativeBuildInputs = [ makeWrapper ];

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentmemory/agentmemory/-/agentmemory-${version}.tgz";
    hash = "sha512-fvnAk8UgCwvNZJMuUrgj7Ac+CSuKo6KgZvTWQkjElU/Y++/g91UcrkfnYJ3RIFAxDxTZ+WkEUphhmOXn34tORQ==";
  };

  postPatch = ''
    cp ${./package-lock.json} package-lock.json
  '';

  npmFlags = [ "--legacy-peer-deps" ];
  npmRebuildFlags = [ "--ignore-scripts" ];
  npmDepsHash = "sha256-VbO5IRLKgmola2H2zO4hRH9QCFLogU86Sb+Ee5DXMCU=";

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
