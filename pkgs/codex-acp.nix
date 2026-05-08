{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "0.0.43";

  inherit nodejs_24;
  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentclientprotocol/codex-acp/-/codex-acp-${version}.tgz";
    hash = "sha512-F2KtiDssyKRIUHblTxuVXPerOOKEQ0BNL9/lehi+0rCaEYANL1LbOOKdMqbMvWnNb8cIMMk+v/RMx/n+dI9iOw==";
  };

  postPatch = ''
    cp ${./codex-acp-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-0UWv4WWOJSHP0fzChLxGf/pzG6kX8lhnUOBI8sQW3lA=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "ACP adapter for OpenAI Codex CLI";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = licenses.asl20;
    mainProgram = "codex-acp";
    platforms = platforms.linux;
  };
}
