{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "droid";
  version = "0.119.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@factory/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
    hash = "sha512-EbU8a6g/PqjmD+qbkOWBrOdNxAU6hSYP+jiEUQXn4swxtRIFiZjCDCkyyQN0BPBMNjGGuiTSoTr4T6wfJk49Jg==";
  };

  sourceRoot = "package";
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/droid $out/bin/droid

    runHook postInstall
  '';

  meta = {
    description = "Factory Droid CLI";
    homepage = "https://docs.factory.ai/cli";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-linux" ];
    mainProgram = "droid";
  };
}
