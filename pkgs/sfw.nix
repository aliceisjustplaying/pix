{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "sfw";
  version = "1.12.0";

  src = fetchurl {
    url = "https://github.com/SocketDev/sfw-free/releases/download/v${version}/sfw-free-linux-x86_64";
    hash = "sha256-UYJPAqJC+JLGHEIiPgW36Cu2JHYjN/Amr8KsIp/8rec=";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/bin/sfw"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Socket Firewall Free CLI";
    homepage = "https://github.com/SocketDev/sfw-free";
    license = licenses.unfreeRedistributable;
    mainProgram = "sfw";
    platforms = [ "x86_64-linux" ];
  };
}
