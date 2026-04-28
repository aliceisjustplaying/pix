{ autoPatchelfHook, fetchurl, lib, libcap, openssl, stdenv, stdenvNoCC, xz, zlib }:

stdenvNoCC.mkDerivation rec {
  pname = "codex-acp";
  version = "0.12.0";

  src = fetchurl {
    url = "https://github.com/zed-industries/codex-acp/releases/download/v${version}/codex-acp-${version}-aarch64-unknown-linux-gnu.tar.gz";
    hash = "sha256-4F5hPaZXsrpnMl4moiMT7ZsoKKreK50YGFvoOtFD6c8=";
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [
    libcap
    openssl
    stdenv.cc.cc.lib
    xz
    zlib
  ];

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 codex-acp $out/bin/codex-acp
    runHook postInstall
  '';

  meta = with lib; {
    description = "ACP adapter for the Codex CLI";
    homepage = "https://github.com/zed-industries/codex-acp";
    license = licenses.asl20;
    mainProgram = "codex-acp";
    platforms = [ "aarch64-linux" ];
  };
}
