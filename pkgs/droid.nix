{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-0J/vDvkCh+E+5dlgXYq2xBgGKsFjV0vM82ANFuueC77D3K0EuBqXUYbHK4ZDmjsYkG9nK9T7eI9+BJTPqO3X2g==";
  droidX64Hash = "sha512-JqaJB/4JgM0/Ln0xnOUU3FqCiNc+NZAkBE+B61D1wtrt0ZL9mXGY/7QO61hU4xfz1p6R8hrpn0cvmrMREWcBYA==";
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
  version = "0.150.1";

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
