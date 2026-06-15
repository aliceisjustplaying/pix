{ lib, stdenv, fetchurl }:

let
  droidArm64Hash = "sha512-PdkcsdCTw65M9Z28rz1ZeVO/6IA5f9Of5TSzUi8UCQ3/u9i01RQnpuC4eVTTKnyNgpysQ9zL77IYcxcAlGHZow==";
  droidX64Hash = "sha512-hAf2gdXB6Ehuhp6w0rG3SqRaE7v0vna+vErnelXiG1EShd3UL+MKqYacIsDnF43klZY0NImI1hmGJoOah8hETg==";
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
  version = "0.147.0";

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
