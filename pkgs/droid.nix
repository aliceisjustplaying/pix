{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-mwkYqkP14Fm0i3/cpX08HG0MdicdehEyM0IbSrQrnRbprVPpj+WGSeE3X0imnPKBG4B0SW3Z0ZJuQEfvodPBQg==";
  droidX64Hash = "sha512-X0GuYsOuIdHnpdc4L9sYuf6BthsPKGEz+qx1BrZVK8HzhWtvyjr8obdhwp6+UY81t9IS+cDn5LgfWEtrds2UYQ==";
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
  version = "0.125.1";

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
