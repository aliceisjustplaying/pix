{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-yxtcNl9/260SPUvWGcwE8cdFfCsBdRXAXTKuY4OLT5szjQfhve4dk5R+tHcye7FOwaHjzKA9ffAbMM39yuZtFQ==";
  droidX64Hash = "sha512-D3wBDS5A2+KTCsmUBhqcN0wXHC7ji6Eda7vYMr2suAlFEbgan0HzEPAtqk0/meZZN6z3IYIc2zdYjdTPs0XlBg==";
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
  version = "0.129.0";

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
