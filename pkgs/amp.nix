{ lib, stdenv, fetchurl, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "amp-code";
  version = "0.0.1781191557-g0be3ef";

  src = fetchurl {
    url = "https://registry.npmjs.org/@ampcode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
    hash = "sha512-GDA9FGclPV+tyZN4XgVE6VNwO2UKjbPtYTyS06nrjgd77oBrO0MawoDLoHblSXH+PjjxSvBChMTKwbxn+ha73Q==";
  };

  sourceRoot = "package";
  dontStrip = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  installPhase = ''
    runHook preInstall

    install -Dm755 amp $out/bin/amp
    install -Dm644 LICENSE.md $out/share/doc/amp/LICENSE.md
    install -Dm644 README.md $out/share/doc/amp/README.md

    runHook postInstall
  '';

  meta = {
    description = "CLI for Amp, the frontier coding agent";
    homepage = "https://ampcode.com";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "amp";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
