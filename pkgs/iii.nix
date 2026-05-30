{ fetchurl, lib, stdenv }:

let
  version = "0.16.0";
  targets = {
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-o/koeNFyEHbFQkhX3Qq+EZc2ttVpR50EA6wwQqovEqg=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-YZa0rhvhSCSO1mIUSAOnZpSE9rhto/8SKllOwaAPf+w=";
    };
  };
  platform = targets.${stdenv.hostPlatform.system} or (throw "unsupported platform for iii: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "iii";
  inherit version;

  src = fetchurl {
    url = "https://github.com/iii-hq/iii/releases/download/iii/v${version}/iii-${platform.target}.tar.gz";
    inherit (platform) hash;
  };

  dontConfigure = true;
  dontBuild = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 iii $out/bin/iii
    runHook postInstall
  '';

  meta = with lib; {
    description = "iii engine runtime";
    homepage = "https://github.com/iii-hq/iii";
    license = licenses.asl20;
    mainProgram = "iii";
    platforms = [ "aarch64-linux" "x86_64-linux" ];
  };
}
