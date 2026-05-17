{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-ND1Cn9+hQ3XDJkLC+MrUQVFKmf7mcN0ZUgACJi3fuP8erz1f8w+1dHOWSvlIwFK+4QJ1RJm+36rOrBCCfHgsXw==";
  droidX64Hash = "sha512-OIAqsXFSUWBfJ3cQCKc5AzFj6vWMqNB5yO7pUGK75ahaGbko1cqzUYpRBnVoctxnQMwTHpXKDddCI2d03wD75g==";
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
  version = "0.127.0";

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
