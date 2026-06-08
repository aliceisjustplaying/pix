{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "0.0.45";

  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentclientprotocol/codex-acp/-/codex-acp-${version}.tgz";
    hash = "sha512-f5TEqvSx6mZgmpB4tEZ8s2RSYrENPu0sT2tmV8CUMFvgQNSMV0mcICdG8ZUJb3lHc7oHX3OZoHerKri49ozHaw==";
  };

  postPatch = ''
    cp ${./codex-acp-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-pKlSITafVg6T85qDA/imxTGyiBP1yX2lnoTkYOHqB24=";
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
