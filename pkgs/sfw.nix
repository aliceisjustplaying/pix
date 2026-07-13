{
  lib,
  stdenvNoCC,
  fetchurl,
}:

stdenvNoCC.mkDerivation rec {
  pname = "sfw";
  version = "1.13.1";

  src = fetchurl {
    url = "https://github.com/SocketDev/sfw-free/releases/download/v${version}/sfw-free-linux-x86_64";
    hash = "sha256-TcRrYmp8W4HAtU4ZhO5Tvlpijb+y9VqxTpsEyKE022o=";
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
