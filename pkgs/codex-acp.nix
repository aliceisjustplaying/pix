{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "0.0.38";

  inherit nodejs_24;
  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentclientprotocol/codex-acp/-/codex-acp-${version}.tgz";
    hash = "sha256-odPcXu72IJ50sLSlhjzw9G1xDtg0M7f1ro5/LjB8ex4=";
  };

  postPatch = ''
    cp ${./codex-acp-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-rZb1Kg/A5sDAOoYJCZI52u1W7TNYdws77nbm/G4iC3o=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "ACP adapter for OpenAI Codex CLI";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = licenses.asl20;
    mainProgram = "codex-acp";
    platforms = platforms.linux;
  };
}
