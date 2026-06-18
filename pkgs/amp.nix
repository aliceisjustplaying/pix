{ lib, stdenv, fetchurl, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "amp-code";
  version = "0.0.1781686288-g549e4a";

  src = fetchurl {
    url = "https://registry.npmjs.org/@ampcode/cli-linux-x64/-/cli-linux-x64-${version}.tgz";
    hash = "sha512-TEw/9iqVa8OeIQEsHAiwNPOweQp+Av+8mEYXQsHcBjS8cBSg5uJoU0xBBatEzxEG4FmnatZmFE1NP3R962l9NQ==";
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
