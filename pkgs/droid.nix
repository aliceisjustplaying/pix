{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-8mBSlVHiMYET0ZM8IrBfswGVhOdshf7TmA3neiVwqIPsSsu74UQJVAXmzKFR9cd2DIE+nrpSqQUYNYQHhhLrvg==";
  droidX64Hash = "sha512-vLq80CQa89cPEowEXUC44mYBkAbww2uCH1CYOqxATI8YRIbPxl5TuOb2C1ilIl036zNqlXvOlnDUvtO25jAaVw==";
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
  version = "0.170.0";

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
