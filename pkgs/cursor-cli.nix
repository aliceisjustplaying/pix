{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
  zlib,
}:

let
  release = "2026.05.27-fe9a6e2";
in
stdenv.mkDerivation {
  pname = "cursor-cli";
  version = "0-unstable-2026-05-27";

  src = fetchurl {
    url = "https://downloads.cursor.com/lab/${release}/linux/x64/agent-cli-package.tar.gz";
    hash = "sha256-meBMqjB2se8BuQUKfCofMK+7KPO5ylRjGDstsemC8IE=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    stdenv.cc.cc.lib
    zlib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/share/cursor-agent
    cp -r * $out/share/cursor-agent/
    ln -s $out/share/cursor-agent/cursor-agent $out/bin/cursor-agent
    ln -s $out/share/cursor-agent/cursor-agent $out/bin/agent

    runHook postInstall
  '';

  meta = {
    description = "Cursor CLI";
    homepage = "https://cursor.com/cli";
    license = lib.licenses.unfree;
    mainProgram = "cursor-agent";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
