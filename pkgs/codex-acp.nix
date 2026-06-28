{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "1.0.1";

  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentclientprotocol/codex-acp/-/codex-acp-${version}.tgz";
    hash = "sha512-GTgfS3LXF3MtLk4m/AtlV8sX1MbvV3YQkbjoTBceqkR1Zub65vz5dHkSNHHAr/RNuoJrBHDr8AEgO3iU2yPo3g==";
  };

  postPatch = ''
    cp ${./codex-acp-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-fhudHMusFhCOVJ7nuVstcGpXfBe3WvG5tldXWkWOw6U=";
  npmFlags = [ "--legacy-peer-deps" ];

  dontNpmBuild = true;

  meta = with lib; {
    description = "ACP adapter for OpenAI Codex CLI";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = licenses.asl20;
    mainProgram = "codex-acp";
    platforms = platforms.linux;
  };
}
