{ buildNpmPackage, fetchurl, lib, nodejs_24 }:

buildNpmPackage rec {
  pname = "codex-acp";
  version = "0.0.44";

  inherit nodejs_24;
  nodejs = nodejs_24;

  src = fetchurl {
    url = "https://registry.npmjs.org/@agentclientprotocol/codex-acp/-/codex-acp-${version}.tgz";
    hash = "sha512-iHzFWKzJ0Z8I6yJCkuLZ+nb9mF2WYmfTcHFFvc7sU/awBsQmVBmpSOXOpZ+IK2Dy9cR3iRoML/B2/Wq2/zKBCA==";
  };

  postPatch = ''
    cp ${./codex-acp-package-lock.json} package-lock.json
  '';

  npmDepsHash = "sha256-1VpnhxZ3lzxZ6lhcyh0EUplZ6F3ZMSa3a3Vi1s5ElPo=";

  dontNpmBuild = true;

  meta = with lib; {
    description = "ACP adapter for OpenAI Codex CLI";
    homepage = "https://github.com/agentclientprotocol/codex-acp";
    license = licenses.asl20;
    mainProgram = "codex-acp";
    platforms = platforms.linux;
  };
}
