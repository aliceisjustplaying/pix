{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-CHz3SUTQBIAtAcRI2EOr1pR4qzW9D1XaUg+W7tzTfgeX8u8kB/Q952SqUc2fhYjD4X6ZIgpTd/JpiX6C8IMMag==";
  droidX64Hash = "sha512-dGGNLgxU2dye7tMHHDpPJkBzQU0/Q9/PfB4YAlRwL1KsfWYfKcOjTexk2vrV/LLGYvKAXaB1a+uFpp2Wi19p/Q==";
  sources = {
    aarch64-linux = {
      npmArch = "arm64";
      hash = droidArm64Hash;
    };
    x86_64-linux = {
      npmArch = "x64";
      hash = droidX64Hash;
    };
  };
  source = sources.${stdenv.hostPlatform.system} or (throw "droid: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "droid";
  version = "0.144.2";

  src = fetchurl {
    url = "https://registry.npmjs.org/@factory/cli-linux-${source.npmArch}/-/cli-linux-${source.npmArch}-${version}.tgz";
    inherit (source) hash;
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
    platforms = builtins.attrNames sources;
    mainProgram = "droid";
  };
}
