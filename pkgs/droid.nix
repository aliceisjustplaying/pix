{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-X4o4nSOJc6uxvgZoXn8/jHfkPH9eyopzRv+LrE56tIf09Ya1mropLFq33gxQ3TT8XSOXG0WOFjn1bjZZIogmqg==";
  droidX64Hash = "sha512-jHSlo0gCza/ukov7XYaYgwX57+qVWwXWMXr8PvWLjdKyx5Im7dBUSCubaNGjeBylh/RQ0laGqk16lJBrhm7k7w==";
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
  version = "0.159.1";

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
