{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "1.1.0";

  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentclientprotocol/codex-acp/-/codex-acp-${version}.tgz";
    hash = "sha512-EdUwW6n12yy4khxS6YpOgT8dd4JbVeOP8qPLdCEj795kp85qVI6369EWUXHq1CrnvOmGVwieUMvnrMlsqJaRWg==";
  };

  postPatch = ''
    cp ${./codex-acp-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-odFbKr34xuoB7zNKUz+AF7fFq79fSE/ZAEpeQ1st6Ho=";
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
