{
  autoPatchelfHook,
  fetchurl,
  lib,
  stdenv,
}:

let
  sources = {
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu";
      hash = "sha256-z5Xv5K5fSZ3H3s/bFdKWQll5r8hFrzzdh/4pw/Teog0=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu";
      hash = "sha256-bElwcJer//s7ktqdAxglSa3Z23CkQhJC7OHTMIcbk2U=";
    };
  };
  source = sources.${stdenv.hostPlatform.system} or (throw "tirith: unsupported platform ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation rec {
  pname = "tirith";
  version = "0.3.2";

  src = fetchurl {
    url = "https://github.com/sheeki03/tirith/releases/download/v${version}/tirith-${source.target}.tar.gz";
    hash = source.hash;
  };

  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [
    stdenv.cc.cc.lib
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 tirith "$out/bin/tirith"
    install -Dm644 man/tirith.1 "$out/share/man/man1/tirith.1"
    install -Dm644 completions/tirith.bash "$out/share/bash-completion/completions/tirith"
    install -Dm644 completions/tirith.fish "$out/share/fish/vendor_completions.d/tirith.fish"
    install -Dm644 completions/_tirith "$out/share/zsh/site-functions/_tirith"

    runHook postInstall
  '';

  meta = {
    description = "Terminal security tool";
    homepage = "https://github.com/sheeki03/tirith";
    license = lib.licenses.agpl3Only;
    mainProgram = "tirith";
    platforms = builtins.attrNames sources;
  };
}
