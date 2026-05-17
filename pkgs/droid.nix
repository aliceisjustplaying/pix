{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-VP5PywaSX2HSia/cf+Ax9xF1eMODNF9i0QoMZAhpT6lSh3rmDY7y0l1yqq6KV9DTWtFI3NjO8VbX2ZndEURS7Q==";
  droidX64Hash = "sha512-+a1tOXR2qoKzBlKSqobU8WNsjKXz3xwGS89hY2K+YsURB81XnRDSJQkTIz8LDJ7pgA+LCpuw569rMfQrR8Iq8A==";
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
  version = "0.128.0";

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
