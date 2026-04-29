{
  lib,
  stdenvNoCC,
  fetchurl,
  nodejs_24,
  openssl,
  lsof,
  avahi,
  tailscale,
  sudo,
}:

stdenvNoCC.mkDerivation rec {
  pname = "portless";
  version = "0.11.1";

  src = fetchurl {
    url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
    hash = "sha256-K1FAz6OOCbx2UUNb+dc01i8x6v1y3P1VFrotVCePJuA=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/libexec/portless" "$out/bin"
    cp -R . "$out/libexec/portless/"

    substituteInPlace "$out/libexec/portless/dist/cli.js" \
      --replace-fail 'redirectServer.listen(80);' \
        'redirectServer.listen(80, process.env.PORTLESS_BIND_HOST || undefined);' \
      --replace-fail 'server.listen(proxyPort, () => {' \
        'server.listen(proxyPort, process.env.PORTLESS_BIND_HOST || undefined, () => {'

    cat > "$out/bin/portless" <<EOF
    #!${stdenvNoCC.shell}
    export PATH="${lib.makeBinPath [ openssl lsof avahi tailscale sudo ]}:\$PATH"

    if [ -z "\''${PORTLESS_LAN_IP:-}" ]; then
      portless_tailscale_ip="\$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
      if [ -n "\$portless_tailscale_ip" ]; then
        export PORTLESS_LAN_IP="\$portless_tailscale_ip"
      fi
    fi

    if [ -n "\''${PORTLESS_LAN_IP:-}" ]; then
      export PORTLESS_LAN="\''${PORTLESS_LAN:-1}"
      export PORTLESS_TLD="\''${PORTLESS_TLD:-local}"
      export PORTLESS_HTTPS="\''${PORTLESS_HTTPS:-0}"
    fi

    if [ -n "\''${PORTLESS_LAN_IP:-}" ] && [ -z "\''${PORTLESS_BIND_HOST:-}" ]; then
      export PORTLESS_BIND_HOST="\$PORTLESS_LAN_IP"
    fi

    exec ${nodejs_24}/bin/node "$out/libexec/portless/dist/cli.js" "\$@"
    EOF
    chmod +x "$out/bin/portless"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Replace port numbers with stable, named local URLs";
    homepage = "https://github.com/vercel-labs/portless";
    license = licenses.asl20;
    mainProgram = "portless";
    platforms = platforms.linux;
  };
}
