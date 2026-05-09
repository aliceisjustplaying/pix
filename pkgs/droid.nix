{ lib, stdenv, fetchurl }:

stdenv.mkDerivation rec {
  pname = "droid";
  version = "0.122.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/@factory/cli-linux-arm64/-/cli-linux-arm64-${version}.tgz";
    hash = "sha512-YUVkMIysmJJkpYzsmAJxASGIAErCu+NwlmaqJLmBwQ5e6GAI11YvmHx0w02ZC4IrZdTwNc+4iku0EatHKBc3jg==";
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
