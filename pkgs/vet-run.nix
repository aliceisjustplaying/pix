{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  bash,
  coreutils,
  curl,
  diffutils,
  less,
  shellcheck,
  wget,
}:

stdenvNoCC.mkDerivation rec {
  pname = "vet-run";
  version = "1.0.2";

  src = fetchurl {
    url = "https://github.com/vet-run/vet/releases/download/v${version}/vet";
    hash = "sha256-G4XJj08pvhO5COwiX1OnD5DA2lAldZgQpVlh98YnSHg=";
  };

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 "$src" "$out/libexec/vet/vet"
    patchShebangs "$out/libexec/vet/vet"
    makeWrapper "$out/libexec/vet/vet" "$out/bin/vet" \
      --prefix PATH : ${lib.makeBinPath [
        bash
        coreutils
        curl
        diffutils
        less
        shellcheck
        wget
      ]}

    runHook postInstall
  '';

  meta = {
    description = "Safer way to run remote scripts";
    homepage = "https://github.com/vet-run/vet";
    license = lib.licenses.mit;
    mainProgram = "vet";
    platforms = lib.platforms.linux;
  };
}
