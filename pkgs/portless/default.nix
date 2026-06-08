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

let
  runtimePath = lib.makeBinPath [ openssl lsof avahi tailscale sudo ];
in
stdenvNoCC.mkDerivation rec {
  pname = "portless";
  version = "0.14.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/portless/-/portless-${version}.tgz";
    hash = "sha256-fRBPzQWq4aKUQPZbk222OR6MOoV7irG0BmsMI0KDMZc=";
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

    # Render the wrapper at install time so @libexec@ can resolve to *this*
    # derivation's $out (a separate `replaceVars` derivation would point at
    # its own store path instead).
    substitute ${./wrapper.sh} "$out/bin/portless" \
      --subst-var-by shell ${stdenvNoCC.shell} \
      --subst-var-by runtimePath ${lib.escapeShellArg runtimePath} \
      --subst-var-by node ${nodejs_24}/bin/node \
      --subst-var-by libexec "$out/libexec/portless"
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
