{ lib, stdenvNoCC }:

stdenvNoCC.mkDerivation rec {
  pname = "kickbacks-ai";
  version = "0.3.177";

  # The extension was pulled from the VS Code marketplace (all URLs 404 as of
  # 2026-08-06), so this is a vendored snapshot of the last marketplace build.
  src = ../files/vendor/kickbacks-ai-0.3.177.tar.gz;

  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/kickbacks-ai"
    cp -R extension "$out/share/kickbacks-ai/extension"
    runHook postInstall
  '';

  meta = with lib; {
    description = "Kickbacks.ai VS Code extension assets";
    homepage = "https://kickbacks.ai";
    license = licenses.unfree;
    platforms = platforms.linux;
  };
}
