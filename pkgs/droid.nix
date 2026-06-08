{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-uKaV/aD5TFE2uAsEgnYj4ZZg5HcAtB6TL0EbRbEJhrTTYn2x6vsXN0d7iUs5sB+2HL2HcFg+l3880m2mlEIHlQ==";
  droidX64Hash = "sha512-Bg8gkVQ0cumcGCI87LIOWspZ96Uk1Tbc0EMkjSWNEZ48TcCaO/oR+TupQJYrcEoc36bPkVtaDJkk2UK4HVth7Q==";
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
  version = "0.142.0";

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
