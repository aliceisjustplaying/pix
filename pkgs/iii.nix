{ fetchurl, lib, stdenv }:

let
  version = "0.11.2";
  targets = {
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-4NNe5UprbIpGV2q2YeFxHRHrTa/rG+jh29HMDMtIthU=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-nIPEd4i070vutl3ZvzfpT5k3cM09uHRGTDzhzckjUs0=";
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
