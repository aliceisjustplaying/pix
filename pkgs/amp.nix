{ lib, stdenv, fetchurl, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "amp-code";
  version = "0.0.1782542697-gd6b6a8";

  src = fetchurl {
    url = "https://registry.npmjs.org/@ampcode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
    hash = "sha512-K78qTR6JL7jhsM334or6g40PLj2GvRzEz1Y4zXWP994fL+EyiGSxsbGuy292Qfhzrx3WavE6UGYx8erYlKGaRA==";
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
