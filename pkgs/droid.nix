{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-74+hQntJnKCrGf3PNTuNIDdFhFNqs4ew0Foi5AGudV9iows0w8EBEnYgjbsyIK9i2zAJrkxZV2OiEFig4qQQ/A==";
  droidX64Hash = "sha512-eikHbGcoM50uM3fOv/FQT9VV0mx9Tj36Bpg58ZBxjfXs5aavm6VuqBQATydU6N72lX5KbMs7fLV2zYXbw4Uhtg==";
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
  version = "0.136.1";

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
