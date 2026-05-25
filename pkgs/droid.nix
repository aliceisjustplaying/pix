{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-Pz/NkkAVsUK4tMCezHQvjEbzRsV9nsaHes1dDe9iLyqxwlawwxF17eTy5QmblwCiY4T37es50+GtVKwRcdQlnQ==";
  droidX64Hash = "sha512-GH5oomjVxbSUSDh4VsGfZQUP4slEa/NopebJ0fasfDOoxQmiOfSiu6fq50X69znriGcz9uTPXufpVfjDqO5rvg==";
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
  version = "0.132.1";

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
