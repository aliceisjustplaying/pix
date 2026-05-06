{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "0.0.42";

  inherit nodejs_24;
  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentclientprotocol/codex-acp/-/codex-acp-${version}.tgz";
    hash = "sha512-ByqYVG0het9RbPyCecf83C8db8vr1bSRsS8JKalCLUBQIg7PP7pAVCP6x9dkb+neYKou/s9LRBXu3uoMmtrOPA==";
  };

  postPatch = ''
    cp ${./codex-acp-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-s+RAZcI88DEGBc6Lf9s13EyTw5V0qnqiIZXSiJDKNmQ=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "ACP adapter for OpenAI Codex CLI";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = licenses.asl20;
    mainProgram = "codex-acp";
    platforms = platforms.linux;
  };
}
