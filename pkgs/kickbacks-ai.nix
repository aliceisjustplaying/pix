{ fetchurl, lib, stdenvNoCC, unzip }:

stdenvNoCC.mkDerivation rec {
  pname = "kickbacks-ai";
  version = "0.3.174";

  src = fetchurl {
    url = "https://marketplace.visualstudio.com/_apis/public/gallery/publishers/Kickbacksai/vsextensions/kickbacks-ai/latest/vspackage";
    hash = "sha256-M5tdLPltXsTgQA/BN0CWBspeZ9+HD39fmLdbqibd8n8=";
  };

  nativeBuildInputs = [ unzip ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src" -d source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/kickbacks-ai"
    cp -R source/extension "$out/share/kickbacks-ai/extension"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Kickbacks.ai VS Code extension assets";
    homepage = "https://kickbacks.ai";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
