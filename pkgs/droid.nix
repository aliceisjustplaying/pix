{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "droid";
  version = "0.121.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@factory/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
    hash = "sha512-A/PIH3G0AMEgIPIZDFMxE5fQ/Dx4L6fkWgwSpyDiGMwdMNAVeFbaES2BBBaMg493bvYbMm6EE3pUgxtI8R68JA==";
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
