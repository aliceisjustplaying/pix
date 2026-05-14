{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-WhrvX3MjiJyv/Lx5M+M+0521xF6Qdd585py56ZLoltgZpys2BtVuIf6xpigG6QqdtkcW/a9fwWSvrDFj84QOgQ==";
  droidX64Hash = "sha512-uN/omnulhIdUPefySNImDVhoGzVQDz+q6h2nOJwal5btPdfgEuFP57F2AtMeyv//BDmBA9X+TJ92/s9HyPcWkw==";
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
  version = "0.124.0";

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
