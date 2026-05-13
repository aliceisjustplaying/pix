{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-YUVkMIysmJJkpYzsmAJxASGIAErCu+NwlmaqJLmBwQ5e6GAI11YvmHx0w02ZC4IrZdTwNc+4iku0EatHKBc3jg==";
  droidX64Hash = "sha512-NWT8sKRE+V5QMfWGK+tpxbu7A90pW55Qky9zKYX92VFNWCtD/BawljQk1eHcHwPq+yJNaCsSepC3+jhozjLC9w==";
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
  version = "0.122.0";

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
