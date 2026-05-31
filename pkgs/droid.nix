{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-cNr7pWVc5OaYe4X6SKmxRnAENPND1rEiClZ38sl1PxIoO2KjJHAWYHdKPD3x5r7oosCNz2cSB/jZWA/Xnyoazw==";
  droidX64Hash = "sha512-Q276le8eCfAgrMKOEa09FeX2PctpjEOulsdQyRh3/oTzeyzqfBhUfgIfRA/GvJ4vdSns2yZ+vsYd4+NLnHVffw==";
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
  version = "0.137.1";

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
