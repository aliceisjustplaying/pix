{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-NyT8WhWgFxVfWBxDviOfuI3QkuAmcsrUJPt1RuA6PDAocVgcU+C1aTT17ySRZQkpRM6KgFuWNoei4dIriudxFg==";
  droidX64Hash = "sha512-SxD9od40HCRUREFB2mFhcjd7/y5MMIYCBkQswDo/gyZeIjpmMXZ+o9l7a9oFckpv+BvifzCb4vWRBQeOiogbgA==";
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
  version = "0.134.0";

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
