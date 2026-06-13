{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-CGnjR4xk0UTp7gjCEI4ApvYWs1GhWl+sbYiQGhWEl3Hvf8s3cBN13uUVkSN+fgUuJSe0Pov8At3LpAnflXZxvA==";
  droidX64Hash = "sha512-UmOUm8TkOJlxdC0yLahSAlkClVUt+nd5KAbzgvaDcI2PiHCRL1n+CoZ0jNIYIlhbi7p2ZAX+I3/VKoXkoVyaEg==";
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
  version = "0.146.0";

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
